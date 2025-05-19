class ProjectVendorsController < ApplicationController
  before_action :find_project
  before_action :authorize
  
  # Set the current menu item for proper highlighting
  menu_item :purchase_requests

  def index
    Rails.logger.info "ProjectVendorsController#index called for project: #{@project.try(:identifier)}"
    @vendors = find_vendors
    
    # Use explicit render with rescue for better error handling
    render :index
  rescue => e
    Rails.logger.error "Error rendering project vendors index: #{e.message}\n#{e.backtrace.join("\n")}"
    render plain: "Error loading vendor list. Please check the logs or contact your administrator.", status: 500
  end
  
  def manage
    Rails.logger.info "ProjectVendorsController#manage called for project: #{@project.try(:identifier)}"
    @vendors = find_vendors
    
    # Use explicit render with rescue for better error handling
    render :manage
  rescue => e
    Rails.logger.error "Error rendering project vendors manage: #{e.message}\n#{e.backtrace.join("\n")}"
    render plain: "Error loading vendor management. Please check the logs or contact your administrator.", status: 500
  end
  
  private
  
  def find_project
    # Find by project_id parameter
    project_id = params[:project_id]
    
    if project_id.blank?
      render_404
      return
    end
    
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_vendors
    vendors = Vendor.sorted
    
    # Apply search filter if present
    if params[:search].present?
      begin
        vendors = vendors.search(params[:search])
      rescue => e
        Rails.logger.error "Error searching vendors: #{e.message}"
        flash.now[:error] = l(:error_searching_vendors)
      end
    end
    
    vendors
  end
end
