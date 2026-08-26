class PurchaseRequestsController < ApplicationController
  before_action :find_project, only: [:index, :new, :create, :dashboard]
  before_action :find_purchase_request, only: [:show, :edit, :update, :destroy, :create_workflow_issue]
  before_action :authorize, except: [:show]
  
  # Set the current menu item for proper highlighting
  menu_item :purchase_requests, only: [:index, :new, :create, :show, :edit, :update, :destroy]
  menu_item :purchase_requests_dashboard, only: [:dashboard]
  
  def index
    @limit = per_page_option
    
    scope = @project ? @project.purchase_requests : PurchaseRequest
    
    if params[:status_id].present?
      scope = scope.where(status_id: params[:status_id])
    end
    
    if params[:search].present?
      search_terms = "%#{params[:search].downcase}%"
      scope = scope.where("LOWER(title) LIKE ? OR LOWER(description) LIKE ?", search_terms, search_terms)
    end
    
    @purchase_request_count = scope.count
    @pages = Paginator.new @purchase_request_count, @limit, params[:page]
    @offset ||= @pages.offset
    @purchase_requests = scope.order(created_at: :desc).limit(@limit).offset(@offset)
  end
  
  def show
  end
  
  def new
    @purchase_request = @project.purchase_requests.build
    
    # Pre-fill CAPEX or OPEX if passed as parameters
    if params[:capex_id].present?
      @purchase_request.capex_id = params[:capex_id]
    elsif params[:opex_id].present?
      @purchase_request.opex_id = params[:opex_id]
    end
  end
  
  def create
    @purchase_request = @project.purchase_requests.new(purchase_request_params)
    @purchase_request.user = User.current
    
    # Handle vendor assignment properly
    handle_vendor_assignment
    
    # Handle budget type mutual exclusion
    handle_budget_type_selection
    
    # Set default status if none provided
    if @purchase_request.status_id.nil? && PurchaseRequestStatus.count > 0
      @purchase_request.status = PurchaseRequestStatus.default || PurchaseRequestStatus.first
    end
    
    if @purchase_request.save
      # Handle attachments using Redmine's attachment system
      attachments = Attachment.attach_files(@purchase_request, params[:attachments])
      render_attachment_warning_if_needed(@purchase_request)

      # Handle notifications
      if @purchase_request.notify_manager? && Setting.plugin_redmine_purchase_requests['enable_notifications']
        PurchaseRequestMailer.new_request_notification(@purchase_request).deliver_now
      end

      # Auto-create workflow issue if enabled
      if Setting.plugin_redmine_purchase_requests['workflow_enabled'] == '1' &&
         Setting.plugin_redmine_purchase_requests['workflow_auto_create'] == '1'
        @purchase_request.create_workflow_issue!
      end

      flash[:notice] = l(:notice_purchase_request_created)
      redirect_to project_purchase_request_path(@project, @purchase_request)
    else
      render :new
    end
  end
  
  def edit
    # Load additional data for the edit form
    @statuses = PurchaseRequestStatus.all.sorted
    @vendors = Vendor.all
    @capex_entries = @project ? @project.capex.for_year(Date.current.year).ordered : []
    @opex_entries = @project ? @project.opex.for_year(Date.current.year).ordered : []
    @opex_categories = OpexCategory.all
  end
  
  def update
    # Handle vendor assignment properly
    handle_vendor_assignment
    
    # Handle budget type mutual exclusion
    handle_budget_type_selection
    
    if @purchase_request.update(purchase_request_params)
      # Handle attachments using Redmine's attachment system
      attachments = Attachment.attach_files(@purchase_request, params[:attachments])
      render_attachment_warning_if_needed(@purchase_request)
      
      flash[:notice] = l(:notice_purchase_request_updated)
      redirect_to project_purchase_request_path(@project, @purchase_request)
    else
      render :edit
    end
  end
  
  def destroy
    @purchase_request.destroy
    flash[:notice] = l(:notice_purchase_request_deleted)
    redirect_to project_purchase_requests_path(@project)
  end

  def create_workflow_issue
    if @purchase_request.has_linked_issue?
      flash[:warning] = l(:notice_workflow_issue_exists, default: 'A workflow issue already exists for this purchase request.')
    elsif !@purchase_request.workflow_enabled?
      flash[:error] = l(:text_workflow_not_enabled)
    else
      issue = @purchase_request.create_workflow_issue!
      if issue
        flash[:notice] = l(:notice_workflow_issue_created, default: 'Workflow issue and subtasks have been created.')
      else
        flash[:error] = l(:error_creating_workflow_issue, default: 'Failed to create workflow issue. Please check the plugin settings.')
      end
    end
    redirect_to project_purchase_request_path(@project, @purchase_request)
  end

  def dashboard
    # Collect general statistics for the current project
    scope = @project ? @project.purchase_requests : PurchaseRequest

    # Year filter
    @selected_year = params[:year].present? ? params[:year].to_i : nil
    @available_years = scope.pluck(Arel.sql('DISTINCT YEAR(purchase_requests.created_at)')).compact.sort.reverse
    @available_years = [Date.current.year] if @available_years.empty?

    # The dashboard always describes exactly one year. Annual CAPEX/OPEX
    # budgets don't sum meaningfully across years, so rather than let the
    # budget band show one period while the requests below show "all years",
    # an absent year resolves to the current one and narrows every figure on
    # the page. The band and the request stats can then never disagree.
    @budget_year_defaulted = @selected_year.blank?
    @selected_year ||= Date.current.year
    year_agnostic_scope = scope
    scope = scope.where(Arel.sql('YEAR(purchase_requests.created_at) = ?'), @selected_year)

    # TPC filter
    tpc_scope = @project ? TpcCode.available_for_project(@project) : TpcCode
    @available_tpc_codes = tpc_scope.active.ordered
    @selected_tpc_code_id = params[:tpc_code_id].presence
    if @selected_tpc_code_id
      scope = scope.where(tpc_code_id: @selected_tpc_code_id)
      year_agnostic_scope = year_agnostic_scope.where(tpc_code_id: @selected_tpc_code_id)
    end

    @total_requests = scope.count
    @open_requests = scope.open.count
    @closed_requests = scope.closed.count
    
    # Get default currency for all conversions
    default_currency = Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'

    # ------------------------------------------------------------------
    # Budget-health band: CAPEX + OPEX budget for the resolved year,
    # narrowed by the active TPC filter. `utilized_amount` on both models
    # is the linked purchase-request spend, so these figures stay
    # consistent with the request costs computed below. Currency is
    # converted with the same helper the rest of this action uses.
    # The year was already resolved with the request scope above, so the band
    # and every figure on the page describe the same period.
    # ------------------------------------------------------------------
    @budget_year = @selected_year
    @budget_currency = default_currency

    budget = budget_figures_for(@budget_year, default_currency)
    @capex_budget   = budget[:capex_budget]
    @capex_utilized = budget[:capex_utilized]
    @opex_budget    = budget[:opex_budget]
    @opex_utilized  = budget[:opex_utilized]
    @budget_total     = budget[:total]
    @budget_utilized  = budget[:utilized]
    @budget_remaining = budget[:remaining]
    @budget_utilization_pct = budget[:utilization_pct]
    @has_budget = budget[:has_budget]

    # Optional comparison year. Off unless explicitly chosen — a silent default
    # is what made the old "All Years" control lie. Uses the same figures
    # function, so the currency and scoping rules apply identically.
    @compare_year = params[:compare_year].presence&.to_i
    @compare_year = nil if @compare_year == @selected_year
    if @compare_year
      compare = budget_figures_for(@compare_year, default_currency)
      @compare_budget_total     = compare[:total]
      @compare_budget_utilized  = compare[:utilized]
      @compare_budget_remaining = compare[:remaining]
      @compare_utilization_pct  = compare[:utilization_pct]
      @compare_has_budget       = compare[:has_budget]
      @compare_utilized_delta_pct =
        if @compare_budget_utilized > 0
          (((@budget_utilized - @compare_budget_utilized) / @compare_budget_utilized) * 100).round(1)
        end
    end

    # Calculate total costs with currency conversion
    @total_estimated_cost = 0
    @pending_cost = 0
    @approved_cost = 0
    
    # Process all requests with prices
    scope.where.not(estimated_price: nil).each do |request|
      source_currency = request.currency.presence || default_currency
      converted_price = helpers.convert_currency(request.estimated_price, source_currency, default_currency)
      
      @total_estimated_cost += converted_price
      
      if request.status.is_closed?
        @approved_cost += converted_price
      else
        @pending_cost += converted_price
      end
    end
    
    # Status distribution - with percentage calculation for ApexCharts
    @status_distribution = PurchaseRequestStatus.all.map do |status|
      request_count = scope.where(status_id: status.id).count
      percentage = @total_requests > 0 ? (request_count.to_f / @total_requests * 100).round(1) : 0
      {
        name: status.name,
        count: request_count,
        percentage: percentage,
        color: status.color.presence || '#777777'
      }
    end
    
    # Priority distribution - enhanced for ApexCharts
    @priority_distribution = {
      urgent: scope.where(priority: 'urgent').count,
      high: scope.where(priority: 'high').count,
      normal: scope.where(priority: 'normal').count,
      low: scope.where(priority: 'low').count
    }
    
    # Calculate total for priority percentage
    priority_total = @priority_distribution.values.sum
    @priority_percentages = @priority_distribution.transform_values do |count|
      priority_total > 0 ? (count.to_f / priority_total * 100).round(1) : 0
    end
    
    # Financial statistics with multi-currency support
    default_currency = Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'
    
    # Calculate total estimated costs across all currencies using helper
    @total_estimated_cost = 0
    @pending_cost = 0
    @approved_cost = 0
    
    # Get all purchase requests with prices
    requests_with_prices = scope.where.not(estimated_price: nil)
    
    # Process each request and convert currency
    requests_with_prices.each do |request|
      currency = request.currency.presence || default_currency
      price = request.estimated_price
      
      # Convert currency using helper method
      converted_price = helpers.convert_currency(price, currency, default_currency)
      
      # Add to appropriate totals
      @total_estimated_cost += converted_price
      
      if request.open?
        @pending_cost += converted_price
      else
        @approved_cost += converted_price
      end
    end
    
    # Round totals to 2 decimal places
    @total_estimated_cost = @total_estimated_cost.round(2)
    @pending_cost = @pending_cost.round(2)
    @approved_cost = @approved_cost.round(2)
    
    # Currency distribution with original amounts
    @currency_distribution = {}
    scope.where.not(estimated_price: nil).group(:currency).sum(:estimated_price).each do |currency, amount|
      curr = currency.presence || default_currency
      @currency_distribution[curr] = amount.round(2)
    end
    
    # Currency distribution with converted amounts for comparison
    @converted_currency_distribution = {}
    scope.where.not(estimated_price: nil).group(:currency).sum(:estimated_price).each do |currency, amount|
      curr = currency.presence || default_currency
      converted_amount = helpers.convert_currency(amount, curr, default_currency)
      
      @converted_currency_distribution[curr] = {
        original: amount.round(2),
        converted: converted_amount,
        in_default: "#{converted_amount} #{default_currency}"
      }
    end
    
    # Monthly trends: calendar months of the selected year (never a rolling
    # window — `scope` is year-locked, so a rolling window would render months
    # the filter excludes as permanently-empty bars).
    @monthly_trends = monthly_series_for(@selected_year, year_agnostic_scope, default_currency)

    # Comparison series for the ghost bars, same shape, same code path.
    if @compare_year
      @compare_monthly_trends = monthly_series_for(@compare_year, year_agnostic_scope, default_currency)
    end

    # Create datasets for multi-series monthly chart 
    @monthly_series_data = {
      labels: @monthly_trends.map { |t| t[:month] },
      counts: @monthly_trends.map { |t| t[:count] },
      amounts: @monthly_trends.map { |t| t[:amount] }
    }
    
    # Top vendors with multi-currency support using helpers
    vendor_requests = scope.where.not(vendor: [nil, ''])
                                    .where.not(estimated_price: nil)
    
    vendor_data = {}
    
    vendor_requests.each do |request|
      vendor = request.vendor
      curr = request.currency.presence || default_currency
      converted_price = helpers.convert_currency(request.estimated_price, curr, default_currency)
      
      # Initialize vendor data if needed
      vendor_data[vendor] ||= { count: 0, total_cost: 0 }
      
      # Update vendor data
      vendor_data[vendor][:count] += 1
      vendor_data[vendor][:total_cost] += converted_price
    end
    
    # Format and sort vendors by total cost
    @top_vendors = vendor_data.map do |vendor, data|
      {
        vendor: vendor,
        count: data[:count],
        total_cost: data[:total_cost].round(2)
      }
    end.sort_by { |v| -v[:total_cost] }.take(5)
    
    # Get requests by currency for pie chart
    @requests_by_currency = scope.where.not(estimated_price: nil)
                                          .group(:currency)
                                          .count
                                          .transform_keys { |k| k.presence || default_currency }
    
    # Monthly trends by currency with proper currency conversion
    @currency_monthly_trends = {}
    
    # Get all currencies used in the system
    all_used_currencies = scope.where.not(estimated_price: nil)
                                        .pluck(:currency)
                                        .compact
                                        .uniq
                                        .push(default_currency)
                                        .uniq
    
    # Initialize data structure for each currency
    all_used_currencies.each do |currency|
      @currency_monthly_trends[currency] = 6.times.map do |i|
        {
          month: i.months.ago.strftime("%b %Y"),
          amount: 0,
          converted_amount: 0  # Add field for converted amount
        }
      end.reverse
    end
    
    # Get data for the last 6 months by currency with proper conversion
    6.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_str = i.months.ago.strftime("%b %Y")
      
      # For each currency, get all requests for this month
      all_used_currencies.each do |currency|
        # Get monthly requests for this specific currency
        monthly_requests = scope.where(created_at: month_start..month_end)
                               .where.not(estimated_price: nil)
                               .where(currency: currency)
        
        # Skip if no requests for this currency and month
        next if monthly_requests.empty?
        
        # Calculate both original and converted amounts
        original_amount = monthly_requests.sum(:estimated_price)
        converted_amount = 0
        
        # Convert each request amount individually to ensure accurate conversion
        monthly_requests.each do |request|
          converted_amount += helpers.convert_currency(request.estimated_price, currency, default_currency)
        end
        
        # Find the corresponding month in the data structure
        if @currency_monthly_trends.key?(currency)
          month_idx = @currency_monthly_trends[currency].index { |m| m[:month] == month_str }
          if month_idx
            @currency_monthly_trends[currency][month_idx][:amount] = original_amount.round(2)
            @currency_monthly_trends[currency][month_idx][:converted_amount] = converted_amount.round(2)
          end
        end
      end
      
      # Also handle requests with null currency (defaults to default_currency)
      monthly_null_requests = scope.where(created_at: month_start..month_end)
                                   .where.not(estimated_price: nil)
                                   .where(currency: nil)
      
      if monthly_null_requests.any? && @currency_monthly_trends.key?(default_currency)
        month_idx = @currency_monthly_trends[default_currency].index { |m| m[:month] == month_str }
        if month_idx
          null_amount = monthly_null_requests.sum(:estimated_price)
          @currency_monthly_trends[default_currency][month_idx][:amount] += null_amount.round(2)
          @currency_monthly_trends[default_currency][month_idx][:converted_amount] += null_amount.round(2)
        end
      end
    end
    
    # Average response time calculation - Fixed to correctly calculate time between creation and closure
    closed_requests = scope.joins(:status)
                           .where(purchase_request_statuses: { is_closed: true })
                                    
    if closed_requests.any?
      # Using active record to calculate time differences properly
      total_days = 0
      
      closed_requests.each do |request|
        # For each closed request, calculate the days between creation and the most recent status change
        # This assumes the last update was when the request was closed
        if request.created_at && request.updated_at
          days_to_process = (request.updated_at.to_date - request.created_at.to_date).to_i
          total_days += days_to_process
        end
      end
      
      @avg_response_days = (total_days.to_f / closed_requests.count).round(1)
    else
      @avg_response_days = 0
    end
    
    # Top vendors - with proper currency conversion
    vendor_counts = scope.where.not(vendor: [nil, ''])
                                  .group(:vendor)
                                  .count
                                  
    # Instead of filtering by default currency, process each vendor's requests with currency conversion
    @top_vendors = []
    
    vendor_counts.each do |vendor, count|
      # Get all requests for this vendor
      vendor_requests = scope.where(vendor: vendor).where.not(estimated_price: nil)
      
      # Calculate total cost with currency conversion
      total_cost = 0
      vendor_requests.each do |request|
        source_currency = request.currency.presence || default_currency
        converted_price = helpers.convert_currency(request.estimated_price, source_currency, default_currency)
        total_cost += converted_price
      end
      
      @top_vendors << {
        vendor: vendor,
        count: count,
        total_cost: total_cost.round(2)
      }
    end
    
    # Sort by total cost and take top 5
    @top_vendors.sort_by! { |v| -v[:total_cost] }.take!(5) if @top_vendors.size > 5
    
    # TOP REQUESTERS - Improved with multi-currency support
    # Get users with purchase requests - explicitly select user fields
    @top_requesters = User.joins(:purchase_requests)
                      .select('users.*, COUNT(purchase_requests.id) as request_count')
                      .group('users.id')
                      .order('request_count DESC')
                      .limit(5)
                      .to_a
  
    # Add total cost for each requester with currency conversion
    @top_requesters.each do |user|
      # Get all requests by this user that have a price
      user_priced_requests = scope.where(user_id: user.id)
                                           .where.not(estimated_price: nil)
      
      # Calculate total cost with currency conversion
      total_cost = 0
      
      user_priced_requests.each do |request|
        source_currency = request.currency.presence || default_currency
        converted_price = helpers.convert_currency(request.estimated_price, source_currency, default_currency)
        total_cost += converted_price
      end
      
      # Store the total cost with the user
      user.instance_variable_set(:@total_cost, total_cost.round(2))
      
      # Define a method to access the total cost
      user.define_singleton_method(:total_cost) do
        @total_cost
      end
    end
  
    # Sort requesters by total cost if available, otherwise by request count
    @top_requesters.sort_by! { |user| [-user.total_cost, -user.request_count] }
    
    # Recent requests - add this to fix the empty recent activity list
    @recent_requests = scope.order(created_at: :desc).limit(5)

    # TPC Code distribution with multi-currency support
    tpc_data = {}

    scope.where.not(estimated_price: nil).each do |request|
      tpc_display = request.tpc_code_display
      next if tpc_display.blank?

      curr = request.currency.presence || default_currency
      converted_price = helpers.convert_currency(request.estimated_price, curr, default_currency)

      # Initialize TPC data if needed
      tpc_data[tpc_display] ||= { count: 0, total_cost: 0 }

      # Update TPC data
      tpc_data[tpc_display][:count] += 1
      tpc_data[tpc_display][:total_cost] += converted_price
    end

    # Format and sort TPCs by total cost
    @tpc_distribution = tpc_data.map do |tpc_code, data|
      {
        tpc_code: tpc_code,
        count: data[:count],
        total_cost: data[:total_cost].round(2)
      }
    end.sort_by { |t| -t[:total_cost] }.take(10)
  end
  
  private

  # CAPEX + OPEX budget figures for one year, narrowed by the active project
  # and TPC filter, expressed in `target_currency`. Extracted so the selected
  # year and an optional comparison year are computed by identical code —
  # `utilized_amount` already converts each linked request into its record's
  # currency, so only the record-level figure is converted here.
  def budget_figures_for(year, target_currency)
    capex_scope = Capex.for_year(year)
    opex_scope  = Opex.for_year(year)
    capex_scope = capex_scope.for_project(@project) if @project
    opex_scope  = opex_scope.for_project(@project)  if @project
    if @selected_tpc_code_id
      capex_scope = capex_scope.where(tpc_code_id: @selected_tpc_code_id)
      opex_scope  = opex_scope.where(tpc_code_id: @selected_tpc_code_id)
    end

    capex_budget = 0.0
    capex_utilized = 0.0
    capex_scope.each do |c|
      cur = c.currency.presence || target_currency
      capex_budget   += helpers.convert_currency(c.total_amount || 0, cur, target_currency)
      capex_utilized += helpers.convert_currency(c.utilized_amount || 0, cur, target_currency)
    end

    opex_budget = 0.0
    opex_utilized = 0.0
    opex_scope.each do |o|
      cur = o.currency.presence || target_currency
      opex_budget   += helpers.convert_currency(o.total_amount || 0, cur, target_currency)
      opex_utilized += helpers.convert_currency(o.utilized_amount || 0, cur, target_currency)
    end

    total    = (capex_budget + opex_budget).round(2)
    utilized = (capex_utilized + opex_utilized).round(2)

    {
      capex_budget: capex_budget.round(2),
      capex_utilized: capex_utilized.round(2),
      opex_budget: opex_budget.round(2),
      opex_utilized: opex_utilized.round(2),
      total: total,
      utilized: utilized,
      remaining: (total - utilized).round(2),
      utilization_pct: total > 0 ? (utilized / total * 100).round(1) : 0,
      has_budget: total > 0
    }
  end

  # Request counts/amounts per calendar month of `year`, for the trend chart.
  def monthly_series_for(year, base_scope, default_currency)
    (1..12).map do |month|
      month_start = Date.new(year, month, 1)
      month_end = month_start.end_of_month
      requests = base_scope.where(Arel.sql('YEAR(purchase_requests.created_at) = ?'), year)
                           .where(created_at: month_start..month_end)
      amount = 0
      requests.where.not(estimated_price: nil).each do |r|
        amount += helpers.convert_currency(r.estimated_price, r.currency.presence || default_currency, default_currency)
      end
      { month: month_start.strftime("%b %Y"), count: requests.count, amount: amount.round(2) }
    end
  end
  
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_purchase_request
    @purchase_request = PurchaseRequest.find(params[:id])
    @project = @purchase_request.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def purchase_request_params
    # Build permitted params dynamically based on available columns
    permitted = [
      :title, :description, :status_id, :product_url,
      :estimated_price, :priority, :due_date,
      :notify_manager, :notes, :currency, :capex_id, :opex_id,
      :allocated_quarter, :allocated_amount, :tpc_code_id
      # Note: vendor and vendor_id are excluded here and handled manually in handle_vendor_assignment
    ]

    # Add category_id only if the column exists
    if PurchaseRequest.column_names.include?('category_id')
      permitted << :category_id
    end

    params.require(:purchase_request).permit(permitted)
  end
  
  def handle_vendor_assignment
    # Handle vendor assignment - either vendor_id for existing vendor or vendor for custom vendor name
    vendor_id_param = params[:purchase_request][:vendor_id]
    vendor_param = params[:purchase_request][:vendor]
    
    if vendor_id_param.present? && vendor_id_param != "" && vendor_id_param != "0"
      # Using existing vendor from database
      @purchase_request.vendor_id = vendor_id_param.to_i
      @purchase_request.write_attribute(:vendor, nil)  # Clear custom vendor name using write_attribute
    elsif vendor_param.present? && vendor_param.strip != ""
      # Using custom vendor name
      @purchase_request.write_attribute(:vendor, vendor_param.strip)  # Set custom vendor name using write_attribute
      @purchase_request.vendor_id = nil  # Clear vendor_id
    else
      # Neither provided - clear both (will trigger validation error)
      @purchase_request.vendor_id = nil
      @purchase_request.write_attribute(:vendor, nil)  # Clear vendor name using write_attribute
    end
  end
  
  def handle_budget_type_selection
    # Handle budget type mutual exclusion based on form selection
    budget_type = params[:budget_type]
    
    # If budget_type is not explicitly set, infer it from the form data
    if budget_type.blank?
      if params[:purchase_request] && params[:purchase_request][:capex_id].present?
        budget_type = 'capex'
      elsif params[:purchase_request] && params[:purchase_request][:opex_id].present?
        budget_type = 'opex'
      end
    end
    
    case budget_type
    when 'capex'
      @purchase_request.opex_id = nil
      # Clear category_id when CAPEX is selected (category is only for OPEX)
      @purchase_request.category_id = nil if @purchase_request.respond_to?(:category_id=)
    when 'opex'
      @purchase_request.capex_id = nil
    when 'none'
      @purchase_request.capex_id = nil
      @purchase_request.opex_id = nil
      # Clear category_id when no budget type is selected
      @purchase_request.category_id = nil if @purchase_request.respond_to?(:category_id=)
    end
  end
end

