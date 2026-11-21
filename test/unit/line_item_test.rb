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

class LineItemTest < ActiveSupport::TestCase
  include QboLineItemsTestHelper
  fixtures :journals, :journal_details

  def setup
    @issue = Issue.find(1)
    User.current = User.find(2)
  end

  def teardown
    User.current = nil
  end

  def test_validations
    line = LineItem.new(issue: @issue)
    assert_not line.valid?
    assert line.errors.added?(:description, :blank)
    line = LineItem.new(issue: @issue, description: 'Pads', quantity: 0, unit_price: -1)
    assert_not line.valid?
    assert line.errors.of_kind?(:quantity, :greater_than)
    assert line.errors.of_kind?(:unit_price, :greater_than_or_equal_to)
    assert LineItem.new(issue: @issue, description: 'Shop supplies', quantity: 1, unit_price: 0).valid?
  end

  def test_line_total
    line = add_line(@issue, 'Oil', 2.5, 8.99)
    assert_equal BigDecimal('22.475'), line.line_total.to_d.round(3)
    line.update!(quantity: 4)
    assert_equal BigDecimal('35.96'), line.reload.line_total.to_d
  end

  def test_journal_summary
    line = add_line(@issue, "  Brake\n pads ", 2, 45)
    assert_equal 'Brake pads: 2 × $45.00', line.journal_summary
    line.quantity = 0.5
    assert_equal 'Brake pads: 0.5 × $45.00', line.journal_summary
    assert_equal 'Brake pads: 2 × $45.00', line.journal_summary(saved: true)
  end

  def test_journaled_changes
    line = add_line(@issue)
    assert_not line.journaled_changes?
    line.billed = true
    assert_not line.journaled_changes?
    line.unit_price = 50
    assert line.journaled_changes?
  end

  def test_issues_have_line_items_and_delete_them
    line = add_line(@issue)
    assert_equal [line], @issue.reload.line_items.to_a
    child = Issue.generate!(project_id: 1, parent_issue_id: 1)
    add_line(child, 'Rotor', 1, 120)
    grandchild = Issue.generate!(project_id: 1, parent_issue_id: child.id)
    add_line(grandchild, 'Labor', 2, 100)
    assert_equal 2, @issue.reload.descendant_line_items.count
    assert_equal BigDecimal('320'), @issue.descendant_line_items_total.to_d

    grandchild.reload.destroy
    assert_equal 0, LineItem.where(issue_id: grandchild.id).count
  end

  # ---- line items submitted with the issue ----

  def test_new_lines_need_add_line_items
    allow(:edit_line_items)
    @issue.line_items_attributes = { '0' => { description: 'Pads', quantity: '1', unit_price: '45' } }
    assert_empty @issue.line_items.select(&:new_record?)

    allow(:add_line_items)
    @issue.reload.line_items_attributes = { '0' => { description: 'Pads', quantity: '1', unit_price: '45' },
                                            '1' => { description: '', quantity: '1', unit_price: '0' },
                                            '2' => { description: 'Removed', quantity: '1', unit_price: '1', _destroy: '1' } }
    assert_equal ['Pads'], @issue.line_items.select(&:new_record?).map(&:description)
  end

  def test_arrays_of_lines_work_too
    allow(:add_line_items)
    @issue.line_items_attributes = [{ description: 'Pads', quantity: '1', unit_price: '45' }]
    assert_equal ['Pads'], @issue.line_items.map(&:description)
  end

  def test_changes_need_edit_line_items
    line = add_line(@issue)
    allow(:add_line_items, :delete_line_items)
    @issue.reload.line_items_attributes = { '0' => { id: line.id, description: 'Brake pads', unit_price: '99' } }
    assert_equal 45, @issue.line_items.first.unit_price

    allow(:edit_line_items)
    @issue.reload.line_items_attributes = { '0' => { id: line.id, description: 'Brake pads', unit_price: '99' } }
    assert_equal 99, @issue.line_items.first.unit_price
  end

  def test_removals_need_delete_line_items
    line = add_line(@issue)
    allow(:edit_line_items)
    @issue.reload.line_items_attributes = { '0' => { id: line.id, _destroy: '1' } }
    assert_not @issue.line_items.first.marked_for_destruction?

    allow(:delete_line_items)
    @issue.reload.line_items_attributes = { '0' => { id: line.id, _destroy: 'true' } }
    assert @issue.line_items.first.marked_for_destruction?
  end

  def test_billed_lines_are_locked
    line = add_line(@issue, billed: true)
    allow(:edit_line_items, :delete_line_items)
    @issue.reload.line_items_attributes = { '0' => { id: line.id, description: 'Brake pads', unit_price: '1' }, '1' => { id: line.id, _destroy: '1' } }
    assert_equal 45, @issue.line_items.first.unit_price
    assert_not @issue.line_items.first.marked_for_destruction?
  end

  def test_line_items_are_a_safe_attribute_only_with_a_permission
    assert_not_includes @issue.safe_attribute_names(User.find(2)), 'line_items_attributes'
    allow(:delete_line_items)
    assert_includes @issue.safe_attribute_names(User.find(2)), 'line_items_attributes'
  end

  # ---- history ----

  def test_added_changed_and_removed_lines_are_in_the_history
    allow(:add_line_items, :edit_line_items, :delete_line_items)
    pads = add_line(@issue)
    rotor = add_line(@issue, 'Rotor', 1, 120)
    issue = Issue.find(1)
    issue.init_journal(User.find(2))
    issue.line_items_attributes = { '0' => { description: 'Labor', quantity: '2', unit_price: '100' },
                                    '1' => { id: pads.id, description: 'Brake pads', quantity: '4' },
                                    '2' => { id: rotor.id, _destroy: '1' } }
    issue.save!

    details = issue.journals.last.details.select { |d| d.property == 'line_item' }
    assert_equal 3, details.size
    added = details.detect { |d| d.old_value.nil? }
    assert_equal 'Labor: 2 × $100.00', added.value
    assert_equal LineItem.find_by(description: 'Labor').id.to_s, added.prop_key
    changed = details.detect { |d| d.prop_key == pads.id.to_s }
    assert_equal ['Brake pads: 2 × $45.00', 'Brake pads: 4 × $45.00'], [changed.old_value, changed.value]
    removed = details.detect { |d| d.prop_key == rotor.id.to_s }
    assert_equal ['Rotor: 1 × $120.00', nil], [removed.old_value, removed.value]
  end

  def test_unchanged_lines_are_not_in_the_history
    allow(:edit_line_items)
    pads = add_line(@issue)
    issue = Issue.find(1)
    issue.init_journal(User.find(2), 'Just a note')
    issue.line_items_attributes = { '0' => { id: pads.id, description: 'Brake pads', quantity: '2.0' } }
    issue.save!
    assert_empty issue.journals.last.details.select { |d| d.property == 'line_item' }
  end

  def test_history_shows_line_items_only_to_those_who_may_view_them
    journal = Journal.create!(journalized: @issue, user: User.find(2), notes: 'Parts')
    JournalDetail.create!(journal: journal, property: 'line_item', prop_key: '1', value: 'Pads: 1 × $45.00')
    JournalDetail.create!(journal: journal, property: 'attr', prop_key: 'done_ratio', old_value: '0', value: '10')
    assert_equal ['attr'], journal.reload.visible_details(User.find(2)).map(&:property)
    allow(:view_line_items)
    assert_equal %w[attr line_item], journal.reload.visible_details(User.find(2)).map(&:property).sort
  end

  def test_history_text
    helper = Object.new.extend(ActionView::Helpers::TagHelper, ApplicationHelper, IssuesHelper)
    added = JournalDetail.new(property: 'line_item', prop_key: '1', value: 'Pads: 1 × $45.00')
    changed = JournalDetail.new(property: 'line_item', prop_key: '1', old_value: 'Pads: 1 × $45.00', value: 'Pads: 2 × $45.00')
    removed = JournalDetail.new(property: 'line_item', prop_key: '1', old_value: 'Pads: 2 × $45.00')
    assert_equal 'Line item Pads: 1 × $45.00 added', helper.show_detail(added, true)
    assert_equal 'Line item changed from Pads: 1 × $45.00 to Pads: 2 × $45.00', helper.show_detail(changed, true)
    assert_equal 'Line item deleted (Pads: 2 × $45.00)', helper.show_detail(removed, true)
    assert_equal '<strong>Line item</strong> deleted (<del><i>Pads: 2 × $45.00</i></del>)', helper.show_detail(removed)
    assert_includes helper.show_detail(JournalDetail.new(property: 'attr', prop_key: 'subject', old_value: 'A', value: 'B'), true), 'Subject'
  end

  # ---- billing when the issue is closed ----

  def test_closing_an_issue_with_unbilled_lines_bills_them
    add_line(@issue)
    assert_enqueued_with(job: BillLineItemsJob, args: [@issue.id]) do
      @issue.reload.update!(status_id: 5)
    end
  end

  def test_no_billing_while_open_or_when_all_billed
    add_line(@issue, billed: true)
    assert_no_enqueued_jobs(only: BillLineItemsJob) do
      @issue.reload.update!(subject: 'Still open')
      @issue.update!(status_id: 5)
    end
  end
end
