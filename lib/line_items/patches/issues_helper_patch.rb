#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module LineItems
  module Patches
    # Shows line item changes in an issue's history, emails, PDF and Atom feed. Redmine's show_detail
    # only knows its own kinds of change and returns nothing for others.
    module IssuesHelperPatch
      def show_detail(detail, no_html = false, options = {})
        return super unless detail.property == 'line_item'

        label = l(:label_line_item)
        value = detail.value
        old_value = detail.old_value

        unless no_html
          label = content_tag('strong', label)
          value = content_tag('i', value) if value.present?
          old_value = content_tag('i', old_value) if old_value.present?
          old_value = content_tag('del', old_value) if old_value.present? && value.blank?
        end

        if detail.value.present? && detail.old_value.present?
          l(:text_journal_changed, label: label, old: old_value, new: value).html_safe
        elsif detail.value.present?
          l(:text_journal_added, label: label, value: value).html_safe
        else
          l(:text_journal_deleted, label: label, old: old_value).html_safe
        end
      end
    end
  end
end
