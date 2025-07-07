class ProjectVendorsController < ApplicationController
  before_action :find_project
  before_action :authorize_view, only: [:index]
  before_action :authorize_manage, only: [:manage, :new, :create, :edit, :update, :destroy]
  
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
    
    # Get vendor statistics for the project
    @total_vendors = @vendors.count
    @active_vendors = @vendors.where(is_active: true).count
    @project_specific_vendors = @vendors.where(project_id: @project.id).count rescue 0
    @global_vendors = @vendors.where(project_id: nil).count
    
    render :manage
  rescue => e
    Rails.logger.error "Error rendering project vendor management: #{e.message}\n#{e.backtrace.join("\n")}"
    flash[:error] = l(:error_loading_vendor_management)
    redirect_to project_vendors_path(@project)
  end
  
  def new
    Rails.logger.info "ProjectVendorsController#new called for project: #{@project.try(:identifier)}"
    @vendor = Vendor.new
    @vendor.project_id = @project.id if @project && Vendor.column_names.include?('project_id')
    
    render :new
  rescue => e
    Rails.logger.error "Error rendering new project vendor: #{e.message}\n#{e.backtrace.join("\n")}"
    flash[:error] = "Error loading vendor creation form"
    redirect_to project_vendors_path(@project)
  end

  def create
    Rails.logger.info "ProjectVendorsController#create called for project: #{@project.try(:identifier)}"
    @vendor = Vendor.new(vendor_params)
    
    # Set project_id if the column exists
    if @project && Vendor.column_names.include?('project_id')
      @vendor.project_id = @project.id
    end
    
    if @vendor.save
      flash[:notice] = "Vendor was successfully created for project #{@project.name}."
      redirect_to project_vendors_path(@project)
    else
      render :new
    end
  rescue => e
    Rails.logger.error "Error creating project vendor: #{e.message}\n#{e.backtrace.join("\n")}"
    flash[:error] = "Error creating vendor: #{e.message}"
    render :new
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
    # Show both global vendors and project-specific vendors for this project
    vendors = Vendor.available_for_project(@project).sorted
    
    # Apply search filter if present
    if params[:search].present?
      begin
        vendors = vendors.search(params[:search])
      rescue => e
        Rails.logger.error "Error searching vendors: #{e.message}"
        flash.now[:error] = l(:error_searching_vendors)
      end
    end
    
    # Apply active status filter
    if params[:active].present?
      if params[:active] == 'true'
        vendors = vendors.where(is_active: true)
      elsif params[:active] == 'false'
        vendors = vendors.where(is_active: false)
      end
    end
    
    vendors
  end

  def vendor_params
    params.require(:vendor).permit(:name, :vendor_id, :email, :phone, :contact_person, 
                                   :address, :website, :notes, :is_active, :project_id)
  end

  def authorize_view
    # Check if user is logged in first
    require_login unless User.current.logged?
    
    # Admin users can always access
    return true if User.current.admin?
    
    # Check for specific permission
    User.current.allowed_to?(:view_project_vendors, @project) || render_403
  end

  def authorize_manage
    # Check if user is logged in first
    require_login unless User.current.logged?
    
    # Admin users can always access
    return true if User.current.admin?
    
    # Check for specific permission
    User.current.allowed_to?(:manage_project_vendors, @project) || render_403
  end
end
