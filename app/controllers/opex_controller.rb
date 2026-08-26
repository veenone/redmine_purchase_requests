class OpexController < ApplicationController
  include BudgetDashboard

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
    # utilized_amount enumerates linked requests per record; preload them once
    # rather than issuing a query per row (see Capex dashboard). opex_category
    # is preloaded too: the category grouping below reads it off every loaded
    # record instead of re-querying per category (see that block for why).
    @opex_entries = @project.opex.for_year(@current_year).includes(:purchase_requests, :opex_category)
    @available_tpc_codes = TpcCode.available_for_project(@project).active.ordered
    @selected_tpc_code_id = params[:tpc_code_id].presence
    @opex_entries = @opex_entries.where(tpc_code_id: @selected_tpc_code_id) if @selected_tpc_code_id

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
      # @opex_entries carries .includes(:purchase_requests, :opex_category)
      # (see above) so Opex#utilized_amount and #opex_category don't N+1.
      # Every aggregate below therefore sums over these *materialized*
      # records rather than pushing SUM(:column)/GROUP BY to SQL against
      # @opex_entries directly: Rails silently turns a SQL aggregate call
      # over a relation carrying .includes(has_many) into a
      # LEFT OUTER JOIN, which multiplies an entry's amount by its
      # linked-request count. That hit @total_budget
      # (`@opex_entries.sum(:total_amount)`: 2450.0 rendered vs the true
      # 1450.0), @currency_breakdown, @quarterly_data (q1 alone: 2150.0
      # rendered vs the true 1150.0 — q2-q4 happened to read correctly only
      # because the entry with 2 linked requests has 0 in those columns),
      # and the category grouping's total_budget (same 2450.0 vs 1450.0, both
      # entries fall under the same category here). See task-2-report.md for
      # the full before/after data. `.count` (no column arg) and the
      # block-based `.sum { |o| o.utilized_amount }` calls were never
      # affected — Rails only takes the join-dependency path when a column
      # name is given to the aggregate.
      opex_records = @opex_entries.to_a

      # Currency breakdown and exchange rate settings
      @currency_breakdown = opex_records.group_by(&:currency)
                                         .transform_values { |list| list.sum { |o| o.total_amount || 0 } }

      opex_rates = (Setting.plugin_redmine_purchase_requests || {})
                     .dig('opex_exchange_rates', @current_year.to_s)
      @use_exchange_rates = opex_rates.present?

      # OPEX multiplies by its rate; CAPEX divides by its own. Preserved
      # exactly — reconciling the two conventions is a separate decision.
      # Hoisted to a local so the quarterly breakdown below converts with the
      # SAME arithmetic as the headline totals: rendering converted tiles above
      # unconverted bars, under one currency symbol, is two arithmetics on one
      # page.
      convert = ->(amount, from) {
        @use_exchange_rates ? ((amount || 0) * ((opex_rates || {})[from] || 1)) : (amount || 0)
      }

      figures = budget_dashboard_figures(
        opex_records,
        currency: @default_currency,
        convert: convert,
        missing_rate: (@use_exchange_rates ? ->(cur) { !(opex_rates || {}).key?(cur) } : nil)
      )
      @total_budget           = figures[:total_budget]
      @total_utilized         = figures[:total_utilized]
      @total_remaining        = figures[:total_remaining]
      @utilization_percentage = figures[:utilization_percentage]
      @currencies_mixed        = figures[:currencies_mixed]
      @unconvertible_currencies = figures[:unconvertible_currencies]
      @totals_unreliable      = figures[:totals_unreliable]
      @budget_over            = figures[:over_budget]
      @budget_severity        = figures[:severity]

      # Quarterly breakdown — converted through the same lambda as the totals.
      @quarterly_data = {
        q1: opex_records.sum { |o| convert.call(o.q1_amount, o.currency) }.round(2),
        q2: opex_records.sum { |o| convert.call(o.q2_amount, o.currency) }.round(2),
        q3: opex_records.sum { |o| convert.call(o.q3_amount, o.currency) }.round(2),
        q4: opex_records.sum { |o| convert.call(o.q4_amount, o.currency) }.round(2)
      }

      # Category grouping (similar to TPC grouping in CAPEX). The distinct
      # category-name query below is a plain DISTINCT pluck of names, not an
      # amount aggregate, so it isn't affected by the join-duplication bug
      # and is kept as-is to preserve category display order. Per-category
      # figures come from opex_records (preloaded, filtered/grouped in Ruby)
      # instead of re-querying `.joins(:opex_category).where(...)` per name,
      # which would hit the same SUM(:column)-over-includes bug.
      @category_grouping = {}
      category_names = @opex_entries.joins(:opex_category).distinct.pluck('opex_categories.name')

      category_names.each do |category_name|
        category_entries = opex_records.select { |o| o.opex_category&.name == category_name }
        mixed_group = false

        if @use_exchange_rates
          # Convert all amounts to default currency for category grouping,
          # same as the headline totals above (OPEX multiplies by its rate).
          total_budget = 0
          total_utilized = 0

          category_entries.each do |entry|
            rate = (opex_rates || {})[entry.currency] || 1
            total_budget += (entry.total_amount || 0) * rate
            total_utilized += (entry.utilized_amount || 0) * rate
          end

          total_budget = total_budget.round(2)
          total_utilized = total_utilized.round(2)
          currency_symbol = opex_currency_symbol(@default_currency)
        else
          # Use original amounts
          total_budget = category_entries.sum { |o| o.total_amount || 0 }
          total_utilized = category_entries.sum { |o| o.utilized_amount }

          # Without conversion, a group spanning currencies has no single
          # symbol and its total is a sum of unlike units — say so rather
          # than stamping the first entry's symbol on a number that isn't in
          # that currency (mirrors the CAPEX TPC grouping fix).
          group_currencies = category_entries.map { |o| o.currency.presence }.compact.uniq
          mixed_group = group_currencies.length > 1
          currency_symbol = mixed_group ? '' : (category_entries.first&.currency_symbol || '$')
        end

        entries_count = category_entries.size
        utilization_percentage = total_budget > 0 ? ((total_utilized / total_budget) * 100).round(2) : 0

        @category_grouping[category_name] = {
          mixed_currency: mixed_group,
          total_budget: total_budget,
          total_utilized: total_utilized,
          entries_count: entries_count,
          utilization_percentage: utilization_percentage,
          currency_symbol: currency_symbol
        }
      end

      # Alphabetical is merely what group_by returned. This section answers
      # "which categories are at risk", so the most utilized lead.
      @category_grouping = @category_grouping.sort_by { |_k, d| -d[:utilization_percentage].to_f }.to_h
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
