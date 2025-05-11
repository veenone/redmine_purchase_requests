class PurchaseRequestsController < ApplicationController
  before_action :find_purchase_request, only: [:show, :edit, :update, :destroy]
  before_action :authorize_global
  
  def index
    @purchase_requests = PurchaseRequest.includes(:status)
    
    if params[:status_id].present?
      @purchase_requests = @purchase_requests.where(status_id: params[:status_id])
    end
    
    if params[:search].present?
      search = "%#{params[:search].downcase}%"
      @purchase_requests = @purchase_requests.where("LOWER(title) LIKE ? OR LOWER(description) LIKE ?", search, search)
    end
    
    @purchase_requests = @purchase_requests.order(created_at: :desc)
    
    # Simple pagination that works across all Redmine versions
    @limit = per_page_option
    @purchase_request_count = @purchase_requests.count
    @page = params[:page].to_i > 0 ? params[:page].to_i : 1
    @pages = Redmine::Pagination::Paginator.new(@purchase_request_count, @limit, @page)
    @offset = (@page - 1) * @limit
    
    @purchase_requests = @purchase_requests.limit(@limit).offset(@offset)
  end
  
  def show
  end
  
  def new
    @purchase_request = PurchaseRequest.new
  end
  
  def create
    @purchase_request = PurchaseRequest.new(purchase_request_params)
    @purchase_request.user = User.current
    
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
      redirect_to purchase_request_path(@purchase_request)
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @purchase_request.update(purchase_request_params)
      # Handle attachments using Redmine's attachment system
      attachments = Attachment.attach_files(@purchase_request, params[:attachments])
      render_attachment_warning_if_needed(@purchase_request)
      
      flash[:notice] = l(:notice_purchase_request_updated)
      redirect_to purchase_request_path(@purchase_request)
    else
      render :edit
    end
  end
  
  def destroy
    @purchase_request.destroy
    flash[:notice] = l(:notice_purchase_request_deleted)
    redirect_to purchase_requests_path
  end
  
  def dashboard
    # Collect general statistics
    @total_requests = PurchaseRequest.count
    @open_requests = PurchaseRequest.open.count
    @closed_requests = PurchaseRequest.closed.count
    
    # Status distribution - with percentage calculation for ApexCharts
    @status_distribution = PurchaseRequestStatus.all.map do |status|
      request_count = PurchaseRequest.where(status_id: status.id).count
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
      urgent: PurchaseRequest.where(priority: 'urgent').count,
      high: PurchaseRequest.where(priority: 'high').count,
      normal: PurchaseRequest.where(priority: 'normal').count,
      low: PurchaseRequest.where(priority: 'low').count
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
    requests_with_prices = PurchaseRequest.where.not(estimated_price: nil)
    
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
    PurchaseRequest.where.not(estimated_price: nil).group(:currency).sum(:estimated_price).each do |currency, amount|
      curr = currency.presence || default_currency
      @currency_distribution[curr] = amount.round(2)
    end
    
    # Currency distribution with converted amounts for comparison
    @converted_currency_distribution = {}
    PurchaseRequest.where.not(estimated_price: nil).group(:currency).sum(:estimated_price).each do |currency, amount|
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
      requests = PurchaseRequest.where(created_at: month_start..month_end)
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
    vendor_requests = PurchaseRequest.where.not(vendor: [nil, ''])
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
    @requests_by_currency = PurchaseRequest.where.not(estimated_price: nil)
                                          .group(:currency)
                                          .count
                                          .transform_keys { |k| k.presence || default_currency }
    
    # Monthly trends by currency
    @currency_monthly_trends = {}
    
    # Get all currencies used in the system
    all_used_currencies = PurchaseRequest.where.not(estimated_price: nil)
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
          amount: 0
        }
      end.reverse
    end
    
    # Get data for the last 6 months by currency
    6.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_str = i.months.ago.strftime("%b %Y")
      
      # Get monthly totals by currency
      currency_amounts = PurchaseRequest.where(created_at: month_start..month_end)
                                       .where.not(estimated_price: nil)
                                       .group(:currency)
                                       .sum(:estimated_price)
      
      # Add data to the trends
      currency_amounts.each do |currency, amount|
        curr = currency.presence || default_currency
        if @currency_monthly_trends.key?(curr)
          month_idx = @currency_monthly_trends[curr].index { |m| m[:month] == month_str }
          @currency_monthly_trends[curr][month_idx][:amount] = amount.round(2) if month_idx
        end
      end
    end
    
    # Average response time calculation
    closed_requests = PurchaseRequest.joins(:status)
                                    .where(purchase_request_statuses: { is_closed: true })
                                    
    if closed_requests.any?
      total_days = closed_requests.sum do |request|
        if request.updated_at && request.created_at
          (request.updated_at.to_date - request.created_at.to_date).to_i
        else
          0
        end
      end
      @avg_response_days = (total_days.to_f / closed_requests.count).round(1)
    else
      @avg_response_days = 0
    end
    
    # Top vendors - with better sorting by total cost
    vendor_counts = PurchaseRequest.where.not(vendor: [nil, ''])
                                  .group(:vendor)
                                  .count
                                  
    vendor_costs = PurchaseRequest.where.not(vendor: [nil, ''])
                                 .where.not(estimated_price: nil)
                                 .where(currency: default_currency)
                                 .group(:vendor)
                                 .sum(:estimated_price)
                                 
    @top_vendors = vendor_counts.map do |vendor, count|
      {
        vendor: vendor,
        count: count,
        total_cost: vendor_costs[vendor] || 0
      }
    end.sort_by { |v| -v[:total_cost] }.take(5)
  end
  
  private
  
  def find_purchase_request
    @purchase_request = PurchaseRequest.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def purchase_request_params
    params.require(:purchase_request).permit(
      :title, :description, :status_id, :product_url, 
      :estimated_price, :vendor, :priority, :due_date, 
      :notify_manager, :notes, :currency
    )
  end
end

class PurchaseRequest < ActiveRecord::Base
  # Include the Acts::Attachable module from Redmine
  include Redmine::Acts::Attachable
  
  belongs_to :user
  belongs_to :status, class_name: 'PurchaseRequestStatus', foreign_key: 'status_id'
  
  # Define the model as attachable
  acts_as_attachable
  
  # For Rails 3.x/4.x compatibility
  if Redmine::VERSION::MAJOR < 5
    attr_accessible :title, :description, :status_id, :product_url, 
                  :estimated_price, :vendor, :priority, :due_date, 
                  :notify_manager, :notes
  end
  
  validates :title, presence: true
  validates :status_id, presence: true
  validates :product_url, format: { with: /\Ahttps?:\/\/.*\z/i, 
                                  allow_blank: true,
                                  message: :invalid_url }
  
  # Add any additional scopes or validations as needed
  scope :open, -> { joins(:status).where(purchase_request_statuses: { is_closed: false }) }
  scope :closed, -> { joins(:status).where(purchase_request_statuses: { is_closed: true }) }
  
  def formatted_price
    if estimated_price.present?
      "$#{'%.2f' % estimated_price}"
    else
      "-"
    end
  end
  
  # Simplified workflow methods
  def open?
    !status.is_closed?
  end
  
  def closed?
    status.is_closed?
  end
  
  # Method for checking if manager should be notified
  def notify_manager?
    notify_manager
  end
end

