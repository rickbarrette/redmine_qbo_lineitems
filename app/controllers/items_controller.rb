#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class ItemsController < ApplicationController
  before_action :require_login
  before_action :find_item, only: [:show, :edit, :update, :destroy]

  # Used for autocomplete form
  def autocomplete
    term = ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)

    items = Item.where("description LIKE :t OR name LIKE :t OR sku LIKE :t", t: "%#{term}%")
      .where(active: true)
      .order(:description)
      .limit(20)

    render json: items.map { |i|
      { id: i.id, name: i.name, sku: i.sku, description: i.description, price: i.unit_price }
    }
  end

  def create
    @item = Item.new(item_params)

    if @item.save
      redirect_to item_path(@item), notice: l(:notice_successful_create)
    else
      render :new
    end
  rescue => e
    log "Unexpected error creating item: #{e.message}"

    # Regex now matches across line breaks
    existing_id = e.message[/Duplicate Name Exists Error:[\s\S]*Id=(\d+)/, 1]&.to_i

    if existing_id
      flash[:error] = "Name already exists. Redirecting to existing item."
      redirect_to item_path(existing_id)
    else
      flash[:error] = e.message
      redirect_to new_item_path
    end
  end

  def destroy
    @item.destroy
    redirect_to items_path, notice: l(:notice_successful_delete)
  end

  def edit
  rescue => e
    log "Failed to edit item"
    flash[:error] = e.message
    render_404
  end

  def index
    @items = Item.order(:name)
  end

  def new
    @item = Item.new
    @item.taxable.nil? ? true : @item.taxable
  end

  def show
  end

  def sync
    Item.sync
    redirect_to :home, flash: { notice: I18n.t(:label_syncing) }
  end

  def update
    if @item.update(item_params)
      redirect_to item_path(@item), notice: l(:notice_successful_update)
    else
      render :edit
    end
  end

  private

  def find_item
    @item = Item.find(params[:id])
  rescue => e
    log "Failed to find item"
    flash[:error] = e.message
    render_404
  end

  def item_params
    params.require(:item).permit(:name, :description, :sku, :unit_price, :active, :account_id, :type, :taxable)
  end

  def log(msg)
    Rails.logger.info "[ItemsController] #{msg}"
  end

end