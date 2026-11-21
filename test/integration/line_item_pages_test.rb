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

class LineItemPagesTest < Redmine::IntegrationTest
  include QboLineItemsTestHelper
  fixtures :journals, :journal_details

  def setup
    @issue = Issue.find(1)
  end

  def login(*permissions)
    allow(*permissions)
    reset!
    log_user('jsmith', 'jsmith')
  end

  def test_issue_page_lists_line_items_and_totals
    add_line(@issue, 'Brake pads', 2, 45)
    add_line(@issue, 'Rotor', 1, 120)
    child = Issue.generate!(project_id: 1, parent_issue_id: 1)
    add_line(child, 'Labor', 2, 100)
    login(:view_line_items)
    get '/issues/1'
    assert_response :success
    assert_select 'table.line-items-table tbody tr', 2
    assert_select 'table.line-items-table td', text: 'Brake pads'
    assert_select 'table.line-items-table tfoot', text: /\$210\.00/
    # The whole tree: these lines and the subtasks'
    assert_select 'table.line-items-table tfoot', text: /\(\$410\.00\)/
  end

  def test_line_items_are_hidden_without_view_line_items
    add_line(@issue)
    login
    get '/issues/1'
    assert_response :success
    assert_select 'table.line-items-table', 0
  end

  def test_edit_form_needs_a_line_item_permission
    login(:view_line_items)
    get '/issues/1'
    assert_select '.line-items-sheet', 0

    login(:add_line_items)
    get '/issues/1'
    assert_select '.line-items-sheet' do
      # A blank row to start, and a template for more
      assert_select 'tbody tr.line-item', 1
      assert_select 'template[data-nested-form-template]'
      assert_select 'button[data-nested-form-add]'
    end
  end

  def test_billed_and_uneditable_lines_are_locked
    billed = add_line(@issue, 'Billed line', 1, 10, billed: true)
    add_line(@issue)
    login(:delete_line_items)
    get '/issues/1'
    assert_select '.line-items-sheet' do
      assert_select 'tr.line-item.billed .line-item-billed-badge'
      assert_select 'input.line-item-description[disabled]', 2
      # Only the unbilled line can be removed; no adding without "Add line items"
      assert_select 'button.line-item-remove-button', 1
      assert_select 'button[data-nested-form-add]', 0
    end
    assert billed
  end

  def test_no_form_on_closed_issues
    login(:add_line_items, :edit_line_items)
    get '/issues/8'
    assert_response :success
    assert_select '.line-items-sheet', 0
  end

  def test_adding_lines_through_the_issue_form
    login(:view_line_items, :add_line_items)
    patch '/issues/1', params: { issue: { line_items_attributes: {
      '0' => { description: 'Brake pads', quantity: '2', unit_price: '45', item_id: '' },
      '1' => { description: '', quantity: '1', unit_price: '' }
    } } }
    assert_redirected_to '/issues/1'
    assert_equal ['Brake pads'], @issue.reload.line_items.map(&:description)

    get '/issues/1'
    assert_select '.journal-details li', text: /Line item Brake pads: 2 × \$45\.00 added/
  end

  def test_line_items_are_ignored_without_permissions
    login(:view_line_items)
    patch '/issues/1', params: { issue: { notes: 'Parts', line_items_attributes: {
      '0' => { description: 'Brake pads', quantity: '2', unit_price: '45' }
    } } }
    assert_redirected_to '/issues/1'
    assert_empty @issue.reload.line_items
  end

  def test_the_api_follows_the_same_rules
    with_settings rest_api_enabled: '1' do
      line = add_line(@issue)
      allow(:add_line_items)
      put '/issues/1.json', params: { issue: { line_items_attributes: [
        { id: line.id, description: 'Changed', quantity: '9', unit_price: '1' },
        { description: 'Rotor', quantity: '1', unit_price: '120' }
      ] } }, headers: credentials('jsmith')
      assert_response :no_content
      assert_equal ['Brake pads', 'Rotor'], @issue.reload.line_items.order(:id).map(&:description)
    end
  end

  def test_history_of_line_items_is_hidden_without_view_line_items
    journal = Journal.create!(journalized: @issue, user: User.find(2))
    JournalDetail.create!(journal: journal, property: 'line_item', prop_key: '1', value: 'Brake pads: 1 × $45.00')
    login
    get '/issues/1'
    assert_select '.journal-details li', text: /Brake pads/, count: 0
    login(:view_line_items)
    get '/issues/1'
    assert_select '.journal-details li', text: /Line item Brake pads: 1 × \$45\.00 added/
  end

  def test_closing_the_issue_bills_the_lines
    add_line(@issue)
    login(:view_line_items)
    assert_enqueued_with(job: BillLineItemsJob, args: [1]) do
      patch '/issues/1', params: { issue: { status_id: 5 } }
    end
  end

  def test_item_search_needs_add_or_edit
    login(:view_line_items)
    get '/items/autocomplete', params: { q: 'brake' }
    assert_response :forbidden
    login(:edit_line_items)
    get '/items/autocomplete', params: { q: 'brake' }
    assert_response :success
  end
end
