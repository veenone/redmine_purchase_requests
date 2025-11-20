class TpcCodesController < ApplicationController
  before_action :find_project, only: [:index, :show, :new, :create, :edit, :update, :destroy, :import_export, :import, :export]
  before_action :find_tpc_code, only: [:show, :edit, :update, :destroy]
  before_action :authorize_global, only: [:global_index, :global_show, :global_new, :global_create, :global_edit, :global_update, :global_destroy, :global_import_export, :global_import, :global_export]
  before_action :find_global_tpc_code, only: [:global_show, :global_edit, :global_update, :global_destroy]
  
  def index
    @tpc_codes = TpcCode.available_for_project(@project)
    @tpc_codes = @tpc_codes.search(params[:search]) if params[:search].present?
    @tpc_codes = @tpc_codes.active if params[:active] == 'true'
    @tpc_codes = @tpc_codes.inactive if params[:active] == 'false'
    @tpc_codes = @tpc_codes.ordered
    
    @tpc_codes_count = @tpc_codes.count
    @tpc_codes_pages = Redmine::Pagination::Paginator.new @tpc_codes_count, 25, params['page']
    @tpc_codes = @tpc_codes.limit(@tpc_codes_pages.per_page).offset(@tpc_codes_pages.offset)
  end
  
  def global_index
    @tpc_codes = TpcCode.global
    @tpc_codes = @tpc_codes.search(params[:search]) if params[:search].present?
    @tpc_codes = @tpc_codes.active if params[:active] == 'true'
    @tpc_codes = @tpc_codes.inactive if params[:active] == 'false'
    @tpc_codes = @tpc_codes.ordered
    
    @tpc_codes_count = @tpc_codes.count
    @tpc_codes_pages = Redmine::Pagination::Paginator.new @tpc_codes_count, 25, params['page']
    @tpc_codes = @tpc_codes.limit(@tpc_codes_pages.per_page).offset(@tpc_codes_pages.offset)
    
    render 'index'
  end
  
  def show
  end
  
  def global_show
    @tpc_code = @global_tpc_code
    render 'show'
  end
  
  def new
    @tpc_code = TpcCode.new
    @tpc_code.project = @project
    @tpc_code.is_active = true
  end
  
  def global_new
    @tpc_code = TpcCode.new
    @tpc_code.is_active = true
    render 'new'
  end
  
  def create
    @tpc_code = TpcCode.new(tpc_code_params)
    @tpc_code.project = @project
    
    if @tpc_code.save
      flash[:notice] = l(:notice_tpc_code_created)
      redirect_to project_tpc_code_path(@project, @tpc_code)
    else
      render :new
    end
  end
  
  def global_create
    @tpc_code = TpcCode.new(tpc_code_params)
    @tpc_code.project = nil  # Global TPC code
    
    if @tpc_code.save
      flash[:notice] = l(:notice_tpc_code_created)
      redirect_to global_tpc_code_path(@tpc_code)
    else
      render :new
    end
  end
  
  def edit
  end
  
  def global_edit
    @tpc_code = @global_tpc_code
    render 'edit'
  end
  
  def update
    if @tpc_code.update(tpc_code_params)
      flash[:notice] = l(:notice_tpc_code_updated)
      redirect_to project_tpc_code_path(@project, @tpc_code)
    else
      render :edit
    end
  end
  
  def global_update
    @tpc_code = @global_tpc_code
    if @tpc_code.update(tpc_code_params)
      flash[:notice] = l(:notice_tpc_code_updated)
      redirect_to global_tpc_code_path(@tpc_code)
    else
      render :edit
    end
  end
  
  def destroy
    if @tpc_code.can_be_deleted?
      @tpc_code.destroy
      flash[:notice] = l(:notice_tpc_code_deleted)
    else
      flash[:error] = l(:error_tpc_code_has_linked_capex)
    end
    redirect_to project_tpc_codes_path(@project)
  end
  
  def global_destroy
    @tpc_code = @global_tpc_code
    if @tpc_code.can_be_deleted?
      @tpc_code.destroy
      flash[:notice] = l(:notice_tpc_code_deleted)
    else
      flash[:error] = l(:error_tpc_code_has_linked_capex)
    end
    redirect_to global_tpc_codes_path
  end
  
  def import_export
    @tpc_codes_count = TpcCode.available_for_project(@project).count
  end
  
  def global_import_export
    @tpc_codes_count = TpcCode.global.count
    render 'import_export'
  end
  
  def export
    @tpc_codes = TpcCode.available_for_project(@project)
    
    respond_to do |format|
      format.csv do
        send_data @tpc_codes.to_csv, 
                  filename: "tpc_codes_#{@project.identifier}_#{Date.current}.csv",
                  type: 'text/csv'
      end
      format.json do
        send_data @tpc_codes.to_json_export, 
                  filename: "tpc_codes_#{@project.identifier}_#{Date.current}.json",
                  type: 'application/json'
      end
      format.html do
        redirect_to project_tpc_codes_import_export_path(@project)
      end
    end
  end
  
  def global_export
    @tpc_codes = TpcCode.global
    
    respond_to do |format|
      format.csv do
        send_data @tpc_codes.to_csv, 
                  filename: "global_tpc_codes_#{Date.current}.csv",
                  type: 'text/csv'
      end
      format.json do
        send_data @tpc_codes.to_json_export, 
                  filename: "global_tpc_codes_#{Date.current}.json",
                  type: 'application/json'
      end
      format.html do
        redirect_to global_tpc_codes_import_export_path
      end
    end
  end
  
  def import
    unless params[:file].present?
      flash[:error] = l(:error_no_file_selected)
      redirect_to project_tpc_codes_import_export_path(@project)
      return
    end
    
    file = params[:file]
    
    begin
      case file.content_type
      when 'text/csv', 'application/csv'
        results = TpcCode.import_from_csv(file.tempfile.path, @project)
      when 'application/json'
        results = TpcCode.import_from_json(file.tempfile.path, @project)
      else
        flash[:error] = l(:error_unsupported_file_format)
        redirect_to project_tpc_codes_import_export_path(@project)
        return
      end
      
      if results[:errors].any?
        flash[:error] = l(:error_tpc_code_import_failed, error: results[:errors].join(', '))
      else
        flash[:notice] = l(:notice_tpc_codes_imported, count: results[:created], updated: results[:updated])
      end
      
    rescue => e
      flash[:error] = l(:error_tpc_code_import_failed, error: e.message)
    end
    
    redirect_to project_tpc_codes_path(@project)
  end
  
  def global_import
    unless params[:file].present?
      flash[:error] = l(:error_no_file_selected)
      redirect_to global_tpc_codes_import_export_path
      return
    end
    
    file = params[:file]
    
    begin
      case file.content_type
      when 'text/csv', 'application/csv'
        results = TpcCode.import_from_csv(file.tempfile.path, nil)
      when 'application/json'
        results = TpcCode.import_from_json(file.tempfile.path, nil)
      else
        flash[:error] = l(:error_unsupported_file_format)
        redirect_to global_tpc_codes_import_export_path
        return
      end
      
      if results[:errors].any?
        flash[:error] = l(:error_tpc_code_import_failed, error: results[:errors].join(', '))
      else
        flash[:notice] = l(:notice_tpc_codes_imported, count: results[:created], updated: results[:updated])
      end
      
    rescue => e
      flash[:error] = l(:error_tpc_code_import_failed, error: e.message)
    end
    
    redirect_to global_tpc_codes_path
  end
  
  private
  
  def find_project
    @project = Project.find(params[:project_id]) if params[:project_id]
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_tpc_code
    @tpc_code = TpcCode.available_for_project(@project).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_global_tpc_code
    @global_tpc_code = TpcCode.global.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def authorize_global
    # Check if user can manage global TPC codes (admin or manage_purchase_requests permission)
    unless User.current.admin? || User.current.allowed_to?(:manage_purchase_requests, nil, global: true)
      render_403
      return false
    end
  end
  
  def tpc_code_params
    params.require(:tpc_code).permit(:tpc_number, :tpc_owner_name, :department, :tpc_email, :description, :is_active, :notes)
  end
end
