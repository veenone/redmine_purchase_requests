class OpexCategoriesController < ApplicationController
  layout 'base'
  before_action :require_admin
  before_action :find_category, only: [:edit, :update, :destroy]

  def index
    @categories = OpexCategory.all
  end

  def create
    @category = OpexCategory.new(category_params)
    if @category.save
      flash[:notice] = l(:notice_successful_create)
    else
      flash[:error] = @category.errors.full_messages.join(', ')
    end
    redirect_to settings_plugin_path('redmine_purchase_requests', tab: 'opex_categories')
  end

  def edit
  end

  def update
    if @category.update(category_params)
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = @category.errors.full_messages.join(', ')
    end
    redirect_to settings_plugin_path('redmine_purchase_requests', tab: 'opex_categories')
  end

  def destroy
    if @category.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = @category.errors.full_messages.join(', ')
    end
    redirect_to settings_plugin_path('redmine_purchase_requests', tab: 'opex_categories')
  end

  private
  def find_category
    @category = OpexCategory.find(params[:id])
  end

  def category_params
    params.require(:opex_category).permit(:name)
  end
end
