#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class ItemService

  # Initializes the service with a QBO client and an optional item record. The QBO client is used to communicate with QuickBooks Online, while the item record contains the data that needs to be pushed to QBO. If no item is provided, the service will not perform any operations.
  def initialize(qbo:, item: nil)
    raise "No QBO configuration found" unless qbo
    raise "Item record is required for push operation" unless item
    @qbo = qbo
    @item = item
  end

  def build_qbo_item
    log "Building new QBO Item"
    account = default_income_account
    log "Account: #{account.id} - #{account.name}"
    income = Quickbooks::Model::BaseReference.new
    income.value = account.id
    income.name  = account.name

    Quickbooks::Model::Item.new(
      type: Quickbooks::Model::Item::NON_INVENTORY_TYPE,
      income_account_ref: income
    )
  end

  def default_income_account
    log "Looking up sales income account"
    qbo = QboConnectionService.current!
    qbo.perform_authenticated_request do |token|
      service = Quickbooks::Service::Account.new(
        company_id: qbo.realm_id,
        access_token: token
      )
      service.query("SELECT * FROM Account WHERE AccountType='Income' AND Name LIKE '%Sales%'").first
    end
  end

  # Pulls the Item data from QuickBooks Online. 
  def pull
    return Quickbooks::Model::Item.new unless @item.present?
    return build_qbo_item unless @item.id
    log "Fetching details for item ##{@item.id} from QBO..."
    qbo = QboConnectionService.current!
    qbo.perform_authenticated_request do |access_token|
      service = Quickbooks::Service::Item.new(
        company_id: qbo.realm_id,
        access_token: access_token
      )
      service.fetch_by_id(@item.id)
    end
  rescue => e
    log "Fetch failed for #{@item.id}: #{e.message}"
    build_qbo_item
  end

   # Pushes the Item data to QuickBooks Online. This method handles the communication with QBO, including authentication and error handling. It uses the QBO client to send the item data and logs the process for monitoring and debugging purposes. If the push is successful, it returns the item record; otherwise, it logs the error and returns false.
  def push
    log "Pushing item ##{@item.id} to QBO..."

    item = @qbo.perform_authenticated_request do |access_token|
      service = Quickbooks::Service::Item.new( 
        company_id: @qbo.realm_id, 
        access_token: access_token 
      )
      if @item.id.present?
        service.update(@item.details)
      else
        service.create(@item.details)
      end
    end

    @item.id = item.id unless @item.persisted?
    log "Push for item ##{@item.id} completed."
    return @item
  end

  private 

  # Log messages with the entity type for better traceability
  def log(msg)
    Rails.logger.info "[ItemService] #{msg}"
  end

end