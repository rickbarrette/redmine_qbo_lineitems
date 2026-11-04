#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class LineItem < ApplicationRecord
  belongs_to :issue
  belongs_to :item, optional: true

  validates :description, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  before_save :total

  # The fields whose changes are recorded in the issue's history
  JOURNALED_ATTRIBUTES = %w[description quantity unit_price item_id].freeze

  # A one-line summary for the issue's history, e.g. "Brake pads: 2 × $45.00".
  # With saved: true it describes the line as it is in the database, before any unsaved changes.
  def journal_summary(saved: false)
    desc, qty, price = %w[description quantity unit_price].map { |a| saved ? attribute_in_database(a) : self[a] }
    qty = ActiveSupport::NumberHelper.number_to_rounded(qty.to_d, precision: 4, strip_insignificant_zeros: true)
    price = ActiveSupport::NumberHelper.number_to_currency(price.to_d)
    "#{desc.to_s.squish}: #{qty} × #{price}"
  end

  # True when a field shown in the issue's history has an unsaved change
  def journaled_changes?
    (changed & JOURNALED_ATTRIBUTES).any?
  end

  private

  def total
    log "Updating line total"
    self.line_total = self.unit_price * self.quantity
  end

  def log(msg)
    Rails.logger.info "[LineItem] #{msg}"
  end

end