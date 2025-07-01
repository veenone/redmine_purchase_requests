class OpexController < ApplicationController
  layout 'base'
  before_action :find_project
  before_action :find_opex, only: [:show, :edit, :update, :destroy]
  before_action :authorize
  
  helper :purchase_requests
  include PurchaseRequestsHelper
  
  def index
    @year = params[:year] || Date.current.year
    @category = params[:category]
    @search = params[:search]
    
    @opex_entries = @project.opex.ordered
    @opex_entries = @opex_entries.for_year(@year) if @year.present?
    @opex_entries = @opex_entries.for_category(@category) if @category.present?
    @opex_entries = @opex_entries.search(@search) if @search.present?
    
    @years = @project.opex.distinct.pluck(:year).sort.reverse
    @categories = OpexCategory.all.pluck(:name, :id)
    
    respond_to do |format|
      format.html
      format.json { render json: @opex_entries.map(&:as_json) }
    end
  end
  
  def show
    @linked_requests = @opex.purchase_requests.includes(:user, :status)
  end
  
  def new
    @opex = @project.opex.build
    @opex.year = Date.current.year
    @opex.currency = default_currency
  end
  
  def create
    @opex = @project.opex.build(opex_params)
    @opex.project = @project
    
    if @opex.save
      flash[:notice] = l(:notice_opex_created)
      redirect_to project_opex_index_path(@project)
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @opex.update(opex_params)
      flash[:notice] = l(:notice_opex_updated)
      redirect_to project_opex_path(@project, @opex)
    else
      render :edit
    end
  end
  
  def destroy
    if @opex.purchase_requests.any?
      flash[:error] = l(:error_opex_has_linked_requests)
      redirect_to project_opex_index_path(@project)
    else
      @opex.destroy
      flash[:notice] = l(:notice_opex_deleted)
      redirect_to project_opex_index_path(@project)
    end
  end
  
  def dashboard
    @year = params[:year] || Date.current.year
    @opex_entries = @project.opex.for_year(@year)
    
    # Statistics
    @total_budget = @opex_entries.sum(:total_amount)
    @utilized_budget = @opex_entries.sum { |o| o.utilized_amount }
    @remaining_budget = @total_budget - @utilized_budget
    @average_utilization = @opex_entries.any? ? 
      (@opex_entries.sum { |o| o.utilization_percentage } / @opex_entries.count).round(2) : 0
    
    # Category breakdown
    @category_data = @opex_entries.joins(:opex_category).group('opex_categories.name').sum(:total_amount)
    
    # Monthly trends (quarterly breakdown)
    @quarterly_data = (1..4).map do |quarter|
      {
        quarter: "Q#{quarter}",
        budgeted: @opex_entries.sum("q#{quarter}_amount"),
        utilized: @opex_entries.sum { |o| o.utilized_amount / 4 } # Simplified quarterly utilization
      }
    end
    
    # Currency breakdown with conversion
    @currency_data = calculate_currency_breakdown(@opex_entries, @year)
    
    # Top OPEX entries
    @top_opex = @opex_entries.order(total_amount: :desc).limit(5)
  end
  
  private
  
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_opex
    @opex = @project.opex.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def opex_params
    params.require(:opex).permit(:year, :description, :opex_code, :total_amount, :currency,
                                 :q1_amount, :q2_amount, :q3_amount, :q4_amount, :category_id,
                                 :cost_center, :approved_by, :approved_at, :status, :notes)
  end
  
  def default_currency
    Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'
  end
  
  def calculate_currency_breakdown(opex_entries, year)
    breakdown = {}
    exchange_rates = get_exchange_rates_for_year(year)
    default_currency = self.default_currency
    
    opex_entries.group(:currency).sum(:total_amount).each do |currency, amount|
      rate = exchange_rates.dig('opex_exchange_rates', year.to_s, currency) || 1
      converted_amount = amount * rate
      
      breakdown[currency] = {
        original_amount: amount,
        converted_amount: converted_amount,
        rate: rate,
        count: opex_entries.where(currency: currency).count
      }
    end
    
    breakdown
  end
  
  def get_exchange_rates_for_year(year)
    Setting.plugin_redmine_purchase_requests || {}
  end
end
