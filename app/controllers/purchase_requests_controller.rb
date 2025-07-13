class PurchaseRequestsController < ApplicationController
  before_action :find_project, only: [:index, :new, :create, :dashboard]
  before_action :find_purchase_request, only: [:show, :edit, :update, :destroy]
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
  
  def dashboard
    # Collect general statistics for the current project
    scope = @project ? @project.purchase_requests : PurchaseRequest
    
    @total_requests = scope.count
    @open_requests = scope.open.count
    @closed_requests = scope.closed.count
    
    # Get default currency for all conversions
    default_currency = Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'
    
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
    
    # Monthly trends with multi-currency support
    @monthly_trends = 12.times.map do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      
      # Get all requests for this month
      requests = scope.where(created_at: month_start..month_end)
      count = requests.count
      
      # Calculate converted total for the month
      monthly_cost = 0
      requests.where.not(estimated_price: nil).each do |request|
        curr = request.currency.presence || default_currency
        monthly_cost += helpers.convert_currency(request.estimated_price, curr, default_currency)
      end
      
      { 
        month: i.months.ago.strftime("%b %Y"),
        count: count,
        amount: monthly_cost.round(2)
      }
    end.reverse
    
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
  end
  
  private
  
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
      :allocated_quarter, :allocated_amount
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

