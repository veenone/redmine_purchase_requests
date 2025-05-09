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
    
    # Status distribution
    @status_distribution = PurchaseRequestStatus.all.map do |status|
      {
        name: status.name,
        count: PurchaseRequest.where(status_id: status.id).count,
        color: status.color.presence || '#777777'
      }
    end
    
    # Priority distribution
    @priority_distribution = {
      urgent: PurchaseRequest.where(priority: 'urgent').count,
      high: PurchaseRequest.where(priority: 'high').count,
      normal: PurchaseRequest.where(priority: 'normal').count,
      low: PurchaseRequest.where(priority: 'low').count
    }
    
    # Financial statistics with currency support
    default_currency = Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'
    @total_estimated_cost = PurchaseRequest.where.not(estimated_price: nil).where(currency: default_currency).sum(:estimated_price)
    @pending_cost = PurchaseRequest.open.where.not(estimated_price: nil).where(currency: default_currency).sum(:estimated_price)
    @approved_cost = PurchaseRequest.closed.where.not(estimated_price: nil).where(currency: default_currency).sum(:estimated_price)
    
    # Currency distribution
    @currency_distribution = {}
    PurchaseRequest.where.not(estimated_price: nil).group(:currency).sum(:estimated_price).each do |currency, amount|
      @currency_distribution[currency || default_currency] = amount
    end
    
    # Most active requesters (top 5) - alternative approach without join
    # First get user_ids and count from purchase requests
    user_counts = PurchaseRequest.group(:user_id).count
    
    # Sort by count descending and take top 5
    top_user_ids = user_counts.sort_by { |_, count| -count }.take(5).map { |user_id, _| user_id }
    
    # Now fetch users with those ids, in correct order
    @top_requesters = []
    top_user_ids.each do |user_id|
      user = User.find_by(id: user_id)
      if user
        # Add the count to the user object
        user.instance_variable_set(:@request_count, user_counts[user_id])
        def user.request_count
          @request_count
        end
        @top_requesters << user
      end
    end
    
    # Recent activity
    @recent_requests = PurchaseRequest.includes(:user, :status)
                                     .order(created_at: :desc)
                                     .limit(10)
    
    # Monthly trends - requests created per month (last 6 months)
    @monthly_trends = 6.times.map do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      count = PurchaseRequest.where(created_at: month_start..month_end).count
      { 
        month: i.months.ago.strftime("%b %Y"),
        count: count
      }
    end.reverse
    
    # Average response time (from creation to first status change)
    # This is a simplified calculation and might need adjustment based on your workflow
    @avg_response_days = 3.5 # Placeholder - replace with actual calculation
    
    # Top vendors - handle missing or empty vendor names
    vendor_counts = PurchaseRequest.where.not(vendor: [nil, ''])
                                  .group(:vendor)
                                  .count
                                  
    vendor_costs = PurchaseRequest.where.not(vendor: [nil, ''])
                                 .where.not(estimated_price: nil)
                                 .group(:vendor)
                                 .sum(:estimated_price)
                                 
    @top_vendors = vendor_counts.map do |vendor, count|
      {
        vendor: vendor,
        count: count,
        total_cost: vendor_costs[vendor] || 0
      }
    end.sort_by { |v| -v[:count] }.take(5)
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

