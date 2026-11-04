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
    module IssuePatch extend ActiveSupport::Concern
      
      prepended do
        has_many :line_items, dependent: :destroy

        # Bill unbilled line items to a QBO estimate when the issue is closed, however it was closed
        # (issue form, bulk edit, context menu or API)
        after_commit :enqueue_line_items_billing, on: :update

        def enqueue_line_items_billing
          return unless closed?
          return unless line_items.where(billed: [false, nil]).exists?

          Rails.logger.info "[LineItems::IssuePatch] Enqueuing line item billing for issue ##{id}"
          BillLineItemsJob.perform_later(id)
        end
        accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: proc { |attrs| attrs['description'].blank? }

        # Record added, changed and removed line items in the issue's history (the journal Redmine is
        # already writing for this update). Changes are collected before saving, while the old values are
        # still known, and written after the line items are saved, so new lines have their ids.
        # The after_update must be declared after accepts_nested_attributes_for: it then runs after the
        # line items are saved, and before Redmine's after_save that saves the journal.
        before_save :collect_line_item_changes
        after_update :journalize_line_item_changes

        def collect_line_item_changes
          @line_item_changes = nil
          return unless current_journal

          # Only lines touched in this request are loaded into the association, so this doesn't query
          @line_item_changes = association(:line_items).target.filter_map do |line|
            if line.new_record?
              [:added, line, nil] unless line.marked_for_destruction?
            elsif line.marked_for_destruction?
              [:removed, line, line.journal_summary(saved: true)]
            elsif line.journaled_changes?
              [:changed, line, line.journal_summary(saved: true)]
            end
          end
        end

        def journalize_line_item_changes
          changes = @line_item_changes
          @line_item_changes = nil
          return if changes.blank? || current_journal.nil?

          changes.each do |action, line, old_summary|
            case action
            when :added
              add_line_item_detail(line, nil, line.journal_summary) if line.persisted?
            when :removed
              add_line_item_detail(line, old_summary, nil) if line.destroyed?
            when :changed
              new_summary = line.journal_summary
              add_line_item_detail(line, old_summary, new_summary) unless new_summary == old_summary
            end
          end
        end

        def add_line_item_detail(line, old_value, value)
          current_journal.details << JournalDetail.new(property: 'line_item', prop_key: line.id.to_s,
                                                       old_value: old_value, value: value)
        end

        # Returns line items for immediate children
        def children_line_items
          LineItem.where(issue_id: self.children.pluck(:id))
        end

        # Calculates the total value of all child line items
        def children_line_items_total
          children_line_items.sum(:line_total)
        end

        # Returns line items for the entire tree below this issue
        def descendant_line_items
          LineItem.where(issue_id: self.descendants.pluck(:id))
        end

        # Calculates the total value of entire tree below this issue
        def descendant_line_items_total
          descendant_line_items.sum(:line_total)
        end

        def line_items_total
          line_items.sum(:line_total)
        end

        # Applies line item changes from the issue form, enforcing permissions on the server (the form
        # hides buttons, but a request can be crafted by hand or sent through the API):
        # - new lines need "Add line items", changes need "Edit line items", removals need "Delete line items"
        # - billed lines are already on a QuickBooks estimate, so they can't be changed or removed
        # Lines left out of the submission are untouched (Rails never deletes omitted nested records).
        def line_items_attributes=(attrs)
          user = User.current
          can_add = user.allowed_to?(:add_line_items, nil, global: true)
          can_edit = user.allowed_to?(:edit_line_items, nil, global: true)
          can_delete = user.allowed_to?(:delete_line_items, nil, global: true)
          billed_ids = line_items.select(&:billed?).map { |li| li.id.to_s }

          attrs = attrs.each_with_index.to_h { |a, i| [i.to_s, a] } if attrs.is_a?(Array)

          filtered = {}
          attrs.to_h.each do |key, item_attrs|
            item_attrs = item_attrs.to_h.stringify_keys
            id = item_attrs['id'].to_s.presence
            destroy = ActiveModel::Type::Boolean.new.cast(item_attrs['_destroy'])

            if id
              next if billed_ids.include?(id)
              next if destroy ? !can_delete : !can_edit
            else
              # New rows: removed-before-saving or blank rows are dropped
              next if destroy || !can_add || item_attrs['description'].blank?
            end

            filtered[key.to_s] = item_attrs
          end

          super(filtered)
        end

      end
    end
  end
end