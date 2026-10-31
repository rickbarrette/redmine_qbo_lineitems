#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Redmine::Plugin.register :redmine_qbo_lineitems do
  
  # About
  name 'Redmine QBO Line Items plugin'
  author 'Rick Barrette'
  description 'A plugin for Redmine to extend the capabilitys of the Redmine QuickBooks Online plugin to attach billable line items to an isuue'
  version '2026.11.1'
  url 'https://github.com/rickbarrette/redmine_qbo_lineitems'
  author_url 'https://barrettefabrication.com'
  requires_redmine version_or_higher: '6.1.0'

  # Ensure redmine_qbo is installed: it has the QuickBooks product/service list, accounts and estimate
  # writing this plugin uses (from 2026.11.0; generic custom fields from 2026.11.2)
  begin
    requires_redmine_plugin :redmine_qbo, version_or_higher: '2026.11.2'
  rescue Redmine::PluginNotFound
    raise 'Please install the redmine_qbo plugin (https://github.com/rickbarrette/redmine_qbo)'
  end
  
  # Line items can be submitted with an issue only by users who may add, edit or delete them.
  # Which changes are applied is checked per line in Issue#line_items_attributes= (see IssuePatch).
  Issue.safe_attributes :line_items_attributes, if: lambda { |_issue, user|
    %i[add_line_items edit_line_items delete_line_items].any? { |p| user.allowed_to?(p, nil, global: true) }
  }

  # Global Permissions. Line items live on issues; these control what users can do with them there.
  # The item search (redmine_qbo's items#autocomplete) feeds the line item form.
  permission :view_line_items, {}, global: true
  permission :add_line_items, { items: [:autocomplete] }, global: true
  permission :edit_line_items, { items: [:autocomplete] }, global: true
  permission :delete_line_items, {}, global: true
end

RedmineQboLineItems.setup