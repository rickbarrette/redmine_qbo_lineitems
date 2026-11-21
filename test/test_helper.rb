#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require File.expand_path('../../../test/test_helper', __dir__)

module QboLineItemsTestHelper
  PERMISSIONS = %i[view_line_items add_line_items edit_line_items delete_line_items].freeze

  def self.included(base)
    base.include ActiveJob::TestHelper
    base.fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles, :issues, :trackers,
                  :projects_trackers, :issue_statuses, :enabled_modules, :enumerations, :workflows
    base.setup do
      # Redmine's test environment runs jobs inline; queue them instead (billing is tested on its own)
      @saved_queue_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      LineItem.delete_all
      Customer.where(id: 9400..9499).delete_all
      Item.where(id: [9401, 9402]).delete_all
      Role.find(1).remove_permission!(*PERMISSIONS)
    end
    base.teardown { ActiveJob::Base.queue_adapter = @saved_queue_adapter }
  end

  # Gives jsmith's Manager role these line item permissions (and only these)
  def allow(*permissions)
    role = Role.find(1)
    role.remove_permission!(*PERMISSIONS)
    permissions.each { |p| role.add_permission!(p) }
    # The current user caches its roles' permissions
    User.current = User.find(User.current.id) if User.current.logged?
  end

  # A customer, without sending it to QuickBooks
  def create_customer(id = 9401, name = 'Jane Customer')
    customer = Customer.new(id: id, name: name)
    customer.skip_qbo_push = true
    customer.save!
    customer
  end

  def create_item(id: 9401, name: 'Brake pads', taxable: true)
    item = Item.new(id: id, name: name, description: name, unit_price: 45, taxable: taxable)
    item.skip_qbo_push = true
    item.save!
    item
  end

  def add_line(issue, description = 'Brake pads', quantity = 2, unit_price = 45, **attributes)
    LineItem.create!({ issue: issue, description: description, quantity: quantity, unit_price: unit_price }.merge(attributes))
  end
end
