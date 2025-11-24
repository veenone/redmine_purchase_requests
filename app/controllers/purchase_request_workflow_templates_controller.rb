class PurchaseRequestWorkflowTemplatesController < ApplicationController
  before_action :require_admin
  before_action :find_template, only: [:show, :edit, :update, :destroy]

  def index
    @templates = PurchaseRequestWorkflowTemplate.sorted
  end

  def new
    @template = PurchaseRequestWorkflowTemplate.new
    @template.position = (PurchaseRequestWorkflowTemplate.maximum(:position) || 0) + 1
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @template = PurchaseRequestWorkflowTemplate.new(template_params)

    respond_to do |format|
      if @template.save
        flash[:notice] = l(:notice_successful_create, default: 'Workflow template was successfully created.')
        format.html { redirect_to plugin_settings_path('redmine_purchase_requests', tab: 'workflow') }
        format.js
      else
        format.html { render :new }
        format.js
      end
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.js
    end
  end

  def update
    respond_to do |format|
      if @template.update(template_params)
        flash[:notice] = l(:notice_successful_update, default: 'Workflow template was successfully updated.')
        format.html { redirect_to plugin_settings_path('redmine_purchase_requests', tab: 'workflow') }
        format.js
      else
        format.html { render :edit }
        format.js
      end
    end
  end

  def destroy
    @template.destroy
    flash[:notice] = l(:notice_successful_delete, default: 'Workflow template was successfully deleted.')
    redirect_to plugin_settings_path('redmine_purchase_requests', tab: 'workflow')
  end

  def create_defaults
    PurchaseRequestWorkflowTemplate.create_defaults!
    flash[:notice] = l(:notice_default_templates_created, default: 'Default workflow templates have been created.')
    redirect_to plugin_settings_path('redmine_purchase_requests', tab: 'workflow')
  end

  def update_positions
    params[:positions].each do |id, position|
      PurchaseRequestWorkflowTemplate.where(id: id).update_all(position: position)
    end
    head :ok
  end

  private

  def find_template
    @template = PurchaseRequestWorkflowTemplate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def template_params
    params.require(:purchase_request_workflow_template).permit(
      :name, :description, :position, :is_active, :auto_create,
      :tracker_id, :default_assigned_to_id, :estimated_hours
    )
  end
end
