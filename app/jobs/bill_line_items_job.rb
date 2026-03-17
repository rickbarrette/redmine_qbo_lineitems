#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class BillLineItemsJob < ActiveJob::Base
  queue_as :default
  retry_on StandardError, wait: 5.minutes, attempts: 5

  # Creates an estimate for a line items attached to an issue, and then marking those entries as billed in Redmine.
  # This job is typically triggered after an issue is closed.
  def perform(issue)
    return unless issue.customer

    log "Starting billing for issue ##{issue.id}"
    issue.with_lock do
      unbilled_entries = issue.line_items.where(billed: [false, nil]).lock
      return if unbilled_entries.blank?

      qbo = QboConnectionService.current!
      qbo.perform_authenticated_request do |access_token|
        create_estimate(issue, unbilled_entries, access_token, qbo)
      end

      # Only mark billed AFTER successful QBO creation
      unbilled_entries.update_all(billed: true)
    end

    log "Completed billing of for issue ##{issue.id}"
    Qbo.update_time_stamp
  rescue => e
    log "Billing failed for issue ##{issue.id} - #{e.message}"
    raise e
  end

  private

  # Create an Estimate record in QBO for each unbilled line item
  def create_estimate(issue, unbilled_entries, access_token, qbo)
    log "Creating Estimate records in QBO for #{issue.customer.name} from issue ##{issue.id}"
    
    estimate = Quickbooks::Model::Estimate.new(customer_id: issue.customer.id)
    estimate_service = Quickbooks::Service::Estimate.new( company_id: qbo.realm_id, access_token: access_token)
    memo = "Added from: #{issue.tracker} ##{issue.id}: #{issue.subject}"
    estimate.private_note = memo
    estimate.line_items << Quickbooks::Model::InvoiceLineItem.new(description: memo, detail_type: 'DescriptionOnly' )
    
    unbilled_entries.each do |item|
      log "Creating Line Item for #{item.description}"
      line = Quickbooks::Model::InvoiceLineItem.new
      line.amount = item.line_total
      line.description = item.description
      line.sales_item! do |detail|
        detail.unit_price = item.unit_price
        detail.quantity = item.quantity
        detail.tax_code_ref = Quickbooks::Model::BaseReference.new("TAX") item.item.nil? || item.item.taxable
      end

      estimate.line_items << line
    end

    e = estimate_service.create(estimate)
    log "Created estimate ##{e.doc_number}"
  end

  private

  def log(msg)
    Rails.logger.info "[BillLineItemsJob] #{msg}"
  end
end