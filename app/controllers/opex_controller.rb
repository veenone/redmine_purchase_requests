class OpexController < ApplicationController
  layout 'base'
  before_action :find_project
  before_action :find_opex, only: [:show, :edit, :update, :destroy]
  before_action :authorize, except: [:quarterly_data, :dashboard_data]
  before_action :check_quarterly_data_permission, only: [:quarterly_data]
  skip_before_action :verify_authenticity_token, only: [:quarterly_data]
  
  helper :purchase_requests
  include PurchaseRequestsHelper
  
  helper_method :opex_currency_symbol
  
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
  
  # AJAX endpoint to get quarterly data for a specific OPEX entry
  def quarterly_data
    @opex = @project.opex.find(params[:id])
    quarter = params[:quarter].to_i
    
    quarter_amount = case quarter
    when 1 then @opex.q1_amount&.to_f || 0.0
    when 2 then @opex.q2_amount&.to_f || 0.0
    when 3 then @opex.q3_amount&.to_f || 0.0
    when 4 then @opex.q4_amount&.to_f || 0.0
    else 0.0
    end
    
    data = {
      original: quarter_amount,
      currency: @opex.currency || 'USD',
      opex_id: @opex.id,
      quarter: quarter,
      year: @opex.year,
      description: @opex.description,
      category: @opex.category.present? ? @opex.category.name : nil
    }
    
    render json: data
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'OPEX entry not found' }, status: 404
  end
  
  def dashboard
    @current_year = (params[:year] || Date.current.year).to_i
    @opex_entries = @project.opex.for_year(@current_year)
    
    # Initialize variables
    @total_budget = 0
    @total_utilized = 0
    @total_remaining = 0
    @utilization_percentage = 0
    @currency_breakdown = {}
    @quarterly_data = { q1: 0, q2: 0, q3: 0, q4: 0 }
    @category_grouping = {}
    @use_exchange_rates = false
    @default_currency = default_currency
    
    if @opex_entries.any?
      # Currency breakdown and exchange rate settings
      @currency_breakdown = @opex_entries.group(:currency).sum(:total_amount)
      exchange_rates_settings = Setting.plugin_redmine_purchase_requests || {}
      
      if exchange_rates_settings['opex_exchange_rates'] && exchange_rates_settings['opex_exchange_rates'][@current_year.to_s]
        @use_exchange_rates = true
        year_rates = exchange_rates_settings['opex_exchange_rates'][@current_year.to_s]
        
        # Convert all amounts to default currency
        @total_budget = @opex_entries.sum do |opex|
          rate = year_rates[opex.currency] || 1
          opex.total_amount * rate
        end
        
        @total_utilized = @opex_entries.sum do |opex|
          rate = year_rates[opex.currency] || 1
          opex.utilized_amount * rate
        end
      else
        @total_budget = @opex_entries.sum(:total_amount)
        @total_utilized = @opex_entries.sum { |o| o.utilized_amount }
      end
      
      @total_remaining = @total_budget - @total_utilized
      @utilization_percentage = @total_budget > 0 ? ((@total_utilized / @total_budget) * 100).round(2) : 0
      
      # Quarterly breakdown
      @quarterly_data = {
        q1: @opex_entries.sum(:q1_amount),
        q2: @opex_entries.sum(:q2_amount), 
        q3: @opex_entries.sum(:q3_amount),
        q4: @opex_entries.sum(:q4_amount)
      }
      
      # Category grouping (similar to TPC grouping in CAPEX)
      @category_grouping = {}
      category_names = @opex_entries.joins(:opex_category).distinct.pluck('opex_categories.name')
      
      category_names.each do |category_name|
        category_entries = @opex_entries.joins(:opex_category).where('opex_categories.name' => category_name)
        total_budget = category_entries.sum(:total_amount)
        total_utilized = category_entries.sum { |o| o.utilized_amount }
        entries_count = category_entries.count
        utilization_percentage = total_budget > 0 ? ((total_utilized / total_budget) * 100).round(2) : 0
        
        # Get currency symbol from first entry in this category
        first_opex = category_entries.first
        currency_symbol = first_opex&.currency_symbol || '$'
        
        @category_grouping[category_name] = {
          total_budget: total_budget,
          total_utilized: total_utilized,
          entries_count: entries_count,
          utilization_percentage: utilization_percentage,
          currency_symbol: currency_symbol
        }
      end
    end
  end
  
  # AJAX endpoint to get dashboard data
  def dashboard_data
    @current_year = (params[:year] || Date.current.year).to_i
    @opex_entries = @project.opex.for_year(@current_year)
    
    # Apply additional filters if present
    if params[:category].present?
      @opex_entries = @opex_entries.joins(:opex_category).where('opex_categories.name' => params[:category])
    end
    
    if params[:currency].present?
      @opex_entries = @opex_entries.where(currency: params[:currency])
    end
    
    # Initialize variables
    @total_budget = 0
    @total_utilized = 0
    @total_remaining = 0
    @utilization_percentage = 0
    @currency_breakdown = {}
    @quarterly_data = { q1: 0, q2: 0, q3: 0, q4: 0 }
    @category_grouping = {}
    @use_exchange_rates = false
    @default_currency = default_currency
    
    if @opex_entries.any?
      # Currency breakdown and exchange rate settings
      @currency_breakdown = @opex_entries.group(:currency).sum(:total_amount)
      exchange_rates_settings = Setting.plugin_redmine_purchase_requests || {}
      
      if exchange_rates_settings['opex_exchange_rates'] && exchange_rates_settings['opex_exchange_rates'][@current_year.to_s]
        @use_exchange_rates = true
        year_rates = exchange_rates_settings['opex_exchange_rates'][@current_year.to_s]
        
        # Convert all amounts to default currency
        @total_budget = @opex_entries.sum do |opex|
          rate = year_rates[opex.currency] || 1
          opex.total_amount * rate
        end
        
        @total_utilized = @opex_entries.sum do |opex|
          rate = year_rates[opex.currency] || 1
          opex.utilized_amount * rate
        end
      else
        @total_budget = @opex_entries.sum(:total_amount)
        @total_utilized = @opex_entries.sum { |o| o.utilized_amount }
      end
      
      @total_remaining = @total_budget - @total_utilized
      @utilization_percentage = @total_budget > 0 ? ((@total_utilized / @total_budget) * 100).round(2) : 0
      
      # Quarterly breakdown
      @quarterly_data = {
        q1: @opex_entries.sum(:q1_amount),
        q2: @opex_entries.sum(:q2_amount), 
        q3: @opex_entries.sum(:q3_amount),
        q4: @opex_entries.sum(:q4_amount)
      }
      
      # Category grouping (similar to TPC grouping in CAPEX)
      @category_grouping = {}
      category_names = @opex_entries.joins(:opex_category).distinct.pluck('opex_categories.name')
      
      category_names.each do |category_name|
        category_entries = @opex_entries.joins(:opex_category).where('opex_categories.name' => category_name)
        total_budget = category_entries.sum(:total_amount)
        total_utilized = category_entries.sum { |o| o.utilized_amount }
        entries_count = category_entries.count
        utilization_percentage = total_budget > 0 ? ((total_utilized / total_budget) * 100).round(2) : 0
        
        # Get currency symbol from first entry in this category
        first_opex = category_entries.first
        currency_symbol = first_opex&.currency_symbol || '$'
        
        @category_grouping[category_name] = {
          total_budget: total_budget,
          total_utilized: total_utilized,
          entries_count: entries_count,
          utilization_percentage: utilization_percentage,
          currency_symbol: currency_symbol
        }
      end
    end
    
    render json: {
      total_budget: @total_budget,
      total_utilized: @total_utilized,
      total_remaining: @total_remaining,
      utilization_percentage: @utilization_percentage,
      quarterly_data: @quarterly_data,
      currency_breakdown: @currency_breakdown,
      category_grouping: @category_grouping,
      use_exchange_rates: @use_exchange_rates,
      default_currency: @default_currency
    }
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
    params.require(:opex).permit(:year, :description, :opex_code, :tpc_code_id, :total_amount, :currency,
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
  
  def opex_currency_symbol(currency)
    case currency.to_s.upcase
    when 'USD' then '$'
    when 'EUR' then '€'
    when 'GBP' then '£'
    when 'JPY' then '¥'
    when 'CAD' then 'C$'
    when 'AUD' then 'A$'
    when 'CHF' then 'CHF'
    when 'CNY' then '¥'
    when 'SEK' then 'kr'
    when 'NOK' then 'kr'
    when 'DKK' then 'kr'
    when 'PLN' then 'zł'
    when 'CZK' then 'Kč'
    when 'HUF' then 'Ft'
    when 'RUB' then '₽'
    when 'BRL' then 'R$'
    when 'MXN' then '$'
    when 'INR' then '₹'
    when 'KRW' then '₩'
    when 'SGD' then 'S$'
    when 'HKD' then 'HK$'
    when 'NZD' then 'NZ$'
    when 'ZAR' then 'R'
    when 'TRY' then '₺'
    when 'ILS' then '₪'
    when 'AED' then 'د.إ'
    when 'SAR' then '﷼'
    when 'QAR' then 'ر.ق'
    when 'KWD' then 'د.ك'
    when 'BHD' then '.د.ب'
    when 'OMR' then 'ر.ع.'
    when 'JOD' then 'د.ا'
    when 'LBP' then 'ل.ل'
    when 'EGP' then 'ج.م'
    when 'MAD' then 'د.م.'
    when 'TND' then 'د.ت'
    when 'DZD' then 'د.ج'
    when 'LYD' then 'ل.د'
    when 'SDG' then 'ج.س.'
    when 'SOS' then 'Sh'
    when 'ETB' then 'Br'
    when 'KES' then 'Sh'
    when 'UGX' then 'Sh'
    when 'TZS' then 'Sh'
    when 'RWF' then 'Fr'
    when 'MWK' then 'MK'
    when 'ZMW' then 'ZK'
    when 'BWP' then 'P'
    when 'SZL' then 'L'
    when 'LSL' then 'L'
    when 'NAD' then '$'
    when 'MZN' then 'MT'
    when 'MGA' then 'Ar'
    when 'MUR' then '₨'
    when 'SCR' then '₨'
    when 'GMD' then 'D'
    when 'SLL' then 'Le'
    when 'LRD' then '$'
    when 'GHS' then '₵'
    when 'NGN' then '₦'
    when 'XOF' then 'Fr'
    when 'XAF' then 'Fr'
    when 'CVE' then '$'
    when 'STD' then 'Db'
    when 'AOA' then 'Kz'
    when 'CDF' then 'Fr'
    when 'BIF' then 'Fr'
    when 'DJF' then 'Fr'
    when 'ERN' then 'Nfk'
    when 'YER' then '﷼'
    when 'IQD' then 'ع.د'
    when 'IRR' then '﷼'
    when 'AFN' then '؋'
    when 'PKR' then '₨'
    when 'BDT' then '৳'
    when 'BTN' then 'Nu'
    when 'LKR' then '₨'
    when 'MVR' then '.ރ'
    when 'NPR' then '₨'
    when 'MMK' then 'Ks'
    when 'LAK' then '₭'
    when 'KHR' then '៛'
    when 'VND' then '₫'
    when 'THB' then '฿'
    when 'MYR' then 'RM'
    when 'BND' then '$'
    when 'IDR' then 'Rp'
    when 'PHP' then '₱'
    when 'TWD' then 'NT$'
    when 'MNT' then '₮'
    when 'KZT' then '₸'
    when 'KGS' then 'с'
    when 'UZS' then 'сўм'
    when 'TJS' then 'ЅМ'
    when 'TMT' then 'T'
    when 'AZN' then '₼'
    when 'GEL' then '₾'
    when 'AMD' then '֏'
    when 'BYN' then 'Br'
    when 'UAH' then '₴'
    when 'MDL' then 'L'
    when 'RON' then 'lei'
    when 'BGN' then 'лв'
    when 'RSD' then 'дин'
    when 'MKD' then 'ден'
    when 'ALL' then 'L'
    when 'BAM' then 'КМ'
    when 'HRK' then 'kn'
    when 'EUR' then '€'
    else '$'
    end
  end
  
  def check_quarterly_data_permission
    # Allow access if user can view purchase requests in this project
    unless User.current.allowed_to?(:view_purchase_requests, @project)
      render json: { error: 'Unauthorized' }, status: 403
      return false
    end
  end
end
