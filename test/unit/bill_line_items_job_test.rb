#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require File.expand_path('../test_helper', __dir__)

class BillLineItemsJobTest < ActiveSupport::TestCase
  include QboLineItemsTestHelper

  def setup
    @customer = create_customer
    @issue = Issue.find(1)
    @issue.update_columns(customer_id: @customer.id)
    Qbo.stubs(:update_time_stamp)
    @estimate = Struct.new(:doc_number).new('1068')
  end

  def test_bills_unbilled_lines_to_an_estimate
    pads = add_line(@issue, 'Brake pads', 2, 45, item: create_item)
    fluid = add_line(@issue, 'Brake fluid', 1, 12.5, item: create_item(id: 9402, name: 'Fluid', taxable: false))
    supplies = add_line(@issue, 'Shop supplies', 1, 5)
    add_line(@issue, 'Old line', 1, 10, billed: true)
    RedmineQboBilling::IssueValues.stubs(:values_for).with([@issue]).returns('2' => { '1' => VIN_TEXT, '9' => 'x' }, '3' => { '1' => '' })

    memo = "Added from: #{@issue.tracker} #1: #{@issue.subject}"
    RedmineQboBilling::EstimateWriter.expects(:create_estimate).with do |customer:, lines:, private_note:, custom_fields:|
      assert_equal @customer, customer
      assert_equal memo, private_note
      assert_equal({ '2' => VIN_TEXT }, custom_fields)
      assert_equal({ description: memo }, lines.first)
      assert_equal [{ item_id: 9401, description: 'Brake pads', quantity: 2, rate: 45, taxable: true },
                    { item_id: 9402, description: 'Brake fluid', quantity: 1, rate: 12.5, taxable: false },
                    { item_id: nil, description: 'Shop supplies', quantity: 1, rate: 5, taxable: true }],
                   lines.drop(1).map { |l| l.merge(quantity: l[:quantity].to_d, rate: l[:rate].to_d) }
      true
    end.returns(@estimate)
    Qbo.expects(:update_time_stamp)

    BillLineItemsJob.perform_now(@issue.id)
    assert [pads, fluid, supplies].all? { |line| line.reload.billed? }
  end

  VIN_TEXT = '1C4HJXFG0JW123456'

  def test_older_jobs_pass_the_issue
    add_line(@issue)
    RedmineQboBilling::EstimateWriter.expects(:create_estimate).returns(@estimate)
    BillLineItemsJob.perform_now(@issue)
    assert LineItem.last.billed?
  end

  def test_nothing_to_bill
    RedmineQboBilling::EstimateWriter.expects(:create_estimate).never
    add_line(@issue, billed: true)
    BillLineItemsJob.perform_now(@issue.id)
    BillLineItemsJob.perform_now(424242)
    @issue.update_columns(customer_id: nil)
    add_line(@issue)
    BillLineItemsJob.perform_now(@issue.id)
    assert_not LineItem.last.billed?
  end

  def test_lines_stay_unbilled_when_quickbooks_fails
    line = add_line(@issue)
    RedmineQboBilling::EstimateWriter.stubs(:create_estimate).raises(StandardError, 'QuickBooks is down')
    assert_enqueued_with(job: BillLineItemsJob) { BillLineItemsJob.perform_now(@issue.id) }
    assert_not line.reload.billed?
  end
end
