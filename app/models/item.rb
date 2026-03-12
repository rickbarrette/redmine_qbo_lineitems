#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class Item < ApplicationRecord
  belongs_to :issue

  validates_presence_of :id, :description
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  self.primary_key = :id

  # Returns the details of the item. If the details have already been fetched, it returns the cached version. Otherwise, it fetches the details from QuickBooks Online and caches them for future use. This method is used to access the item's information in a way that minimizes unnecessary API calls to QBO, improving performance and reducing latency.
  def details
    @details ||= begin
      xml = Rails.cache.fetch(details_cache_key, expires_in: 10.minutes) do
        fetch_details.to_xml_ns
      end
      Quickbooks::Model::Item.from_xml(xml)
    end
  end

   # Generates a unique cache key for storing this customer's QBO details.
  def details_cache_key
    "item:#{id}:qbo_details:#{updated_at.to_i}"
  end


  # Updates Both local & remote DB description
  def description=(s)
    details
    @details.description = s
    super
  end

  # Returns the last sync time formatted for display. If no sync has occurred, returns a default message.
  def self.last_sync
    return I18n.t(:label_qbo_never_synced) unless maximum(:updated_at)
    format_time(maximum(:updated_at))
  end

  # Magic Method
  # Maps Get/Set methods to QBO item object
  def method_missing(method_name, *args, &block)
    if Quickbooks::Model::Item.method_defined?(method_name)
      details
      @details.public_send(method_name, *args, &block)
    else
      super
    end
  end

  # Updates Both local & remote DB name 
  def name=(s)
    details
    @details.name = s
    super
  end
  
  # Updates Both local & remote DB sku
  def sku=(s)
    details
    @details.sku = s
    super
  end

  # Sync all items, typically triggered by a scheduled task or manual sync request
  def self.sync
    ItemSyncJob.perform_later(full_sync: true)
  end

  # Sync a single items by ID, typically triggered by a webhook notification or manual sync request
  def self.sync_by_id(id)
    ItemSyncJob.perform_later(id: id)
  end

  # Push the updates
  def save_with_push
    log "Starting push for item ##{self.id}..."
    qbo = QboConnectionService.current!
    ItemService.new(qbo: qbo, item: self).push()
    Rails.cache.delete(details_cache_key)
    save_without_push
  end

   alias_method :save_without_push, :save
   alias_method :save, :save_with_push

   # Updates Both local & remote DB price
  def unit_price=(s)
    details
    @details.unit_price = s
    super
  end

  private
  
  def log(msg)
    Rails.logger.info "[Item] #{msg}"
  end

  # Fetches the item's details from QuickBooks Online. 
  def fetch_details
    log "Fetching details for item ##{id} from QBO..."
    qbo = QboConnectionService.current!
    ItemService.new(qbo: qbo, item: self).pull()
  end


end