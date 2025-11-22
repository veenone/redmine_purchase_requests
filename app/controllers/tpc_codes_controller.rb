class TpcCodesController < ApplicationController
  include PurchaseRequestsHelper

  before_action :find_project_for_dashboard, only: [:dashboard]
  before_action :find_project, only: [:index, :show, :new, :create, :edit, :update, :destroy, :import_export, :import, :export]
  before_action :find_tpc_code, only: [:show, :edit, :update, :destroy]
  before_action :authorize_global, only: [:global_index, :global_show, :global_new, :global_create, :global_edit, :global_update, :global_destroy, :global_import_export, :global_import, :global_export]
  before_action :authorize_dashboard, only: [:dashboard]
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

  def dashboard
    # Get TPC codes - filter by project if in project context
    if @project
      @all_tpc_codes = TpcCode.available_for_project(@project).active.includes(:project, :capex, :opex, :purchase_requests)
      base_scope = TpcCode.available_for_project(@project)
      pr_base_scope = @project.purchase_requests
    else
      @all_tpc_codes = TpcCode.active.includes(:project, :capex, :opex, :purchase_requests)
      base_scope = TpcCode
      pr_base_scope = PurchaseRequest
    end

    # Year filter
    @selected_year = params[:year].present? ? params[:year].to_i : nil
    @available_years = pr_base_scope.pluck(Arel.sql('DISTINCT YEAR(purchase_requests.created_at)')).compact.sort.reverse
    tpc_years = base_scope.pluck(Arel.sql('DISTINCT YEAR(tpc_codes.created_at)')).compact
    @available_years = (@available_years + tpc_years).uniq.sort.reverse
    @available_years = [Date.current.year] if @available_years.empty?

    # Apply year filter to purchase request scope if selected
    if @selected_year.present?
      pr_year_scope = pr_base_scope.where(Arel.sql('YEAR(purchase_requests.created_at) = ?'), @selected_year)
    else
      pr_year_scope = pr_base_scope
    end

    # TPC codes by purchase request count (replaces TPC by project)
    @tpc_by_purchase_request = []
    tpc_pr_counts = {}

    # Count direct TPC assignments
    direct_tpc_counts = pr_year_scope.where.not(tpc_code_id: nil).group(:tpc_code_id).count
    direct_tpc_counts.each { |tpc_id, count| tpc_pr_counts[tpc_id] = (tpc_pr_counts[tpc_id] || 0) + count }

    # Count via CAPEX
    capex_tpc_counts = pr_year_scope.joins(:capex).where.not(capex: { tpc_code_id: nil }).group('capex.tpc_code_id').count
    capex_tpc_counts.each { |tpc_id, count| tpc_pr_counts[tpc_id] = (tpc_pr_counts[tpc_id] || 0) + count }

    # Count via OPEX
    opex_tpc_counts = pr_year_scope.joins(:opex).where.not(opex: { tpc_code_id: nil }).group('opex.tpc_code_id').count
    opex_tpc_counts.each { |tpc_id, count| tpc_pr_counts[tpc_id] = (tpc_pr_counts[tpc_id] || 0) + count }

    # Build the chart data
    tpc_pr_counts.each do |tpc_id, count|
      tpc = TpcCode.find_by(id: tpc_id)
      next unless tpc
      @tpc_by_purchase_request << {
        name: tpc.tpc_number,
        count: count,
        department: tpc.department
      }
    end
    @tpc_by_purchase_request = @tpc_by_purchase_request.sort_by { |t| -t[:count] }.take(10)

    # TPC codes by department
    @tpc_by_department = @all_tpc_codes.where.not(department: [nil, '']).group(:department).count

    # Calculate total costs and utilization for each TPC code
    default_currency = Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'
    @tpc_utilization = []

    @all_tpc_codes.limit(20).each do |tpc|
      total_cost = 0
      request_count = 0

      # Get costs from CAPEX entries (filter by project and year if applicable)
      capex_scope = @project ? tpc.capex.where(project_id: @project.id) : tpc.capex
      capex_scope.each do |capex|
        capex_pr_scope = @selected_year ? capex.purchase_requests.where(Arel.sql('YEAR(purchase_requests.created_at) = ?'), @selected_year) : capex.purchase_requests
        capex_pr_scope.each do |pr|
          curr = pr.currency.presence || default_currency
          total_cost += convert_currency(pr.estimated_price || 0, curr, default_currency)
          request_count += 1
        end
      end

      # Get costs from OPEX entries (filter by project and year if applicable)
      opex_scope = @project ? tpc.opex.where(project_id: @project.id) : tpc.opex
      opex_scope.each do |opex|
        opex_pr_scope = @selected_year ? opex.purchase_requests.where(Arel.sql('YEAR(purchase_requests.created_at) = ?'), @selected_year) : opex.purchase_requests
        opex_pr_scope.each do |pr|
          curr = pr.currency.presence || default_currency
          total_cost += convert_currency(pr.estimated_price || 0, curr, default_currency)
          request_count += 1
        end
      end

      # Get costs from direct purchase requests (filter by project and year if applicable)
      pr_scope = @project ? tpc.purchase_requests.where(project_id: @project.id) : tpc.purchase_requests
      pr_scope = pr_scope.where(Arel.sql('YEAR(purchase_requests.created_at) = ?'), @selected_year) if @selected_year
      pr_scope.where.not(estimated_price: nil).each do |pr|
        curr = pr.currency.presence || default_currency
        total_cost += convert_currency(pr.estimated_price, curr, default_currency)
        request_count += 1
      end

      @tpc_utilization << {
        tpc_code: tpc.tpc_number,
        department: tpc.department,
        owner: tpc.tpc_owner_name,
        total_cost: total_cost.round(2),
        request_count: request_count
      }
    end

    @tpc_utilization = @tpc_utilization.sort_by { |t| -t[:total_cost] }.take(10)

    # Active vs Inactive TPCs
    @active_tpcs = base_scope.active.count
    @inactive_tpcs = base_scope.inactive.count

    # Monthly TPC creation trend (last 12 months or selected year)
    if @selected_year
      @monthly_tpc_creation = 12.times.map do |i|
        month_num = i + 1
        month_start = Date.new(@selected_year, month_num, 1)
        month_end = month_start.end_of_month

        {
          month: month_start.strftime("%b"),
          count: base_scope.where(created_at: month_start.beginning_of_day..month_end.end_of_day).count
        }
      end
    else
      @monthly_tpc_creation = 12.times.map do |i|
        month_start = i.months.ago.beginning_of_month
        month_end = i.months.ago.end_of_month

        {
          month: i.months.ago.strftime("%b %Y"),
          count: base_scope.where(created_at: month_start..month_end).count
        }
      end.reverse
    end

    # Monthly TPC usage in purchase requests trend (last 12 months or selected year)
    # Get top 5 TPC codes for the multi-line chart
    top_tpc_ids = @tpc_by_purchase_request.take(5).map { |t| TpcCode.find_by(tpc_number: t[:name])&.id }.compact
    @tpc_usage_legend = @tpc_by_purchase_request.take(5).map { |t| t[:name] }

    if @selected_year
      @monthly_tpc_usage = 12.times.map do |i|
        month_num = i + 1
        month_start = Date.new(@selected_year, month_num, 1)
        month_end = month_start.end_of_month

        month_pr_scope = pr_base_scope.where(created_at: month_start.beginning_of_day..month_end.end_of_day)

        # Get counts per TPC code
        tpc_counts = {}
        top_tpc_ids.each do |tpc_id|
          direct = month_pr_scope.where(tpc_code_id: tpc_id).count
          capex = month_pr_scope.joins(:capex).where(capex: { tpc_code_id: tpc_id }).count
          opex = month_pr_scope.joins(:opex).where(opex: { tpc_code_id: tpc_id }).count
          tpc_counts[tpc_id] = direct + capex + opex
        end

        # Total count for all TPCs
        direct_count = month_pr_scope.where.not(tpc_code_id: nil).count
        capex_count = month_pr_scope.joins(:capex).where.not(capex: { tpc_code_id: nil }).count
        opex_count = month_pr_scope.joins(:opex).where.not(opex: { tpc_code_id: nil }).count

        {
          month: month_start.strftime("%b"),
          total: direct_count + capex_count + opex_count,
          by_tpc: tpc_counts
        }
      end
    else
      @monthly_tpc_usage = 12.times.map do |i|
        month_start = i.months.ago.beginning_of_month
        month_end = i.months.ago.end_of_month

        month_pr_scope = pr_base_scope.where(created_at: month_start..month_end)

        # Get counts per TPC code
        tpc_counts = {}
        top_tpc_ids.each do |tpc_id|
          direct = month_pr_scope.where(tpc_code_id: tpc_id).count
          capex = month_pr_scope.joins(:capex).where(capex: { tpc_code_id: tpc_id }).count
          opex = month_pr_scope.joins(:opex).where(opex: { tpc_code_id: tpc_id }).count
          tpc_counts[tpc_id] = direct + capex + opex
        end

        # Total count for all TPCs
        direct_count = month_pr_scope.where.not(tpc_code_id: nil).count
        capex_count = month_pr_scope.joins(:capex).where.not(capex: { tpc_code_id: nil }).count
        opex_count = month_pr_scope.joins(:opex).where.not(opex: { tpc_code_id: nil }).count

        {
          month: i.months.ago.strftime("%b %Y"),
          total: direct_count + capex_count + opex_count,
          by_tpc: tpc_counts
        }
      end.reverse
    end

    # Convert tpc_counts keys to tpc_numbers for the view
    @monthly_tpc_usage_by_code = {}
    top_tpc_ids.each_with_index do |tpc_id, idx|
      tpc = TpcCode.find_by(id: tpc_id)
      next unless tpc
      @monthly_tpc_usage_by_code[tpc.tpc_number] = @monthly_tpc_usage.map { |m| m[:by_tpc][tpc_id] || 0 }
    end
  end

  private

  def find_project_for_dashboard
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_dashboard
    if @project
      # Project-scoped dashboard - check project permission
      unless User.current.allowed_to?(:view_tpc_dashboard, @project)
        render_403
        return false
      end
    else
      # Global dashboard - check global permission
      unless User.current.admin? || User.current.allowed_to?(:view_global_tpc_codes, nil, global: true)
        render_403
        return false
      end
    end
  end

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
