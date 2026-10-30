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
  # Takes an issue id (jobs queued by older versions pass the Issue itself, which still works)
  def perform(issue_or_id)
    issue = issue_or_id.is_a?(Issue) ? issue_or_id : Issue.find_by(id: issue_or_id)
    return unless issue&.customer

    log "Starting billing for issue ##{issue.id}"
    issue.with_lock do
      unbilled_entries = issue.line_items.where(billed: [false, nil]).lock
      return if unbilled_entries.blank?

      create_estimate(issue, unbilled_entries)

      # Only mark billed AFTER successful QBO creation
      unbilled_entries.update_all(billed: true)
    end

    log "Completed billing of for issue ##{issue.id}"
    Qbo.update_time_stamp
  rescue => e
    log "Billing failed for issue ##{issue&.id || issue_or_id} - #{e.message}"
    raise e
  end

  private

  # Creates the QuickBooks estimate with redmine_qbo_billing, which writes every estimate: a first line
  # saying where the lines came from, then the unbilled line items. The VIN comes from the issue's vehicle.
  def create_estimate(issue, unbilled_entries)
    log "Creating estimate in QBO for #{issue.customer.name} from issue ##{issue.id}"
    memo = "Added from: #{issue.tracker} ##{issue.id}: #{issue.subject}"

    lines = [{ description: memo }]
    unbilled_entries.each do |entry|
      lines << {
        item_id: entry.item_id,
        description: entry.description,
        quantity: entry.quantity,
        rate: entry.unit_price,
        # Taxable unless the item says otherwise (or the line has no item)
        taxable: entry.item.nil? || entry.item.taxable != false
      }
    end

    vin = issue.respond_to?(:vehicle) ? issue.vehicle&.vin : nil
    estimate = RedmineQboBilling::EstimateWriter.create_estimate(customer: issue.customer, lines: lines,
                                                                  private_note: memo, vin: vin)
    log "Created estimate ##{estimate.doc_number}"
  end

  def log(msg)
    Rails.logger.info "[BillLineItemsJob] #{msg}"
  end
end