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
        accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: proc { |attrs| attrs['description'].blank? }

        def line_items_attributes=(attrs)
          attrs = attrs.stringify_keys

          # IDs submitted in the form
          submitted_ids = attrs.values.map { |a| a['id'] }.compact.map(&:to_s)

          # Existing IDs in DB
          existing_ids = line_items.pluck(:id).map(&:to_s)

          # Find missing ones (these would be implicitly deleted by Rails)
          missing_ids = existing_ids - submitted_ids

          # Re-add missing records so Rails doesn't delete them
          missing_ids.each do |id|
            attrs["preserve_#{id}"] = { 'id' => id }
          end

          # Only allow explicit deletes or valid updates/creates
          filtered = attrs.select do |_, item_attrs|
            item_attrs['_destroy'] == '1' ||
              item_attrs['id'].present? ||
              item_attrs['description'].present?
          end

          super(filtered)
        rescue => e
          logger.error "Error processing line items attributes: #{e.message}"
        end

      end
    end
  end
end