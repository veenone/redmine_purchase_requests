class CapexController < ApplicationController
  before_action :find_project
  before_action :authorize, except: [:quarterly_data, :dashboard_data]
  before_action :find_capex, only: [:show, :edit, :update, :destroy]
  before_action :check_quarterly_data_permission, only: [:quarterly_data]
  skip_before_action :verify_authenticity_token, only: [:quarterly_data]
  
  menu_item :purchase_requests

  def index
    @capex_entries = find_capex_entries
    # Get years without ordering to avoid DISTINCT conflict
    @years = @project.capex.distinct.pluck(:year).sort.reverse
    @selected_year = params[:year].present? ? params[:year].to_i : Date.current.year
    
    @capex_entries = @capex_entries.for_year(@selected_year) if @selected_year.present?
    
    respond_to do |format|
      format.html
      format.json { render json: @capex_entries.map(&:as_json) }
    end
  end

  def show
    @purchase_requests = @capex.purchase_requests.includes(:user, :status, :vendor)
  end

  def new
    @capex = @project.capex.build
    @capex.year = Date.current.year
    @capex.currency = Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'
  end

  def create
    @capex = @project.capex.build(capex_params)
    
    if @capex.save
      flash[:notice] = "CAPEX entry created successfully"
      redirect_to project_capex_path(@project, @capex)
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @capex.update(capex_params)
      flash[:notice] = "CAPEX entry updated successfully"
      redirect_to project_capex_path(@project, @capex)
    else
      render :edit
    end
  end

  def destroy
    if @capex.purchase_requests.any?
      flash[:error] = "Cannot delete CAPEX entry with linked purchase requests"
    else
      @capex.destroy
      flash[:notice] = "CAPEX entry deleted successfully"
    end
    redirect_to project_capex_index_path(@project)
  end
  
  # AJAX endpoint to get quarterly data for a specific CAPEX entry
  def quarterly_data
    @capex = @project.capex.find(params[:id])
    quarter = params[:quarter].to_i
    
    quarter_amount = case quarter
    when 1 then @capex.q1_amount&.to_f || 0.0
    when 2 then @capex.q2_amount&.to_f || 0.0
    when 3 then @capex.q3_amount&.to_f || 0.0
    when 4 then @capex.q4_amount&.to_f || 0.0
    else 0.0
    end
    
    data = {
      original: quarter_amount,
      currency: @capex.currency || 'USD',
      capex_id: @capex.id,
      quarter: quarter,
      year: @capex.year,
      description: @capex.description
    }
    
    render json: data
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'CAPEX entry not found' }, status: 404
  end

  def dashboard
    @current_year = params[:year].present? ? params[:year].to_i : Date.current.year
    # Get capex entries for the year without ordering for aggregations
    capex_for_year = @project.capex.for_year(@current_year)
    @capex_entries = capex_for_year.ordered
    
    # Get default currency for conversions
    @default_currency = helpers.default_capex_currency
    @use_exchange_rates = helpers.capex_use_exchange_rates?
    
    # Calculate summary statistics using unordered relation
    if @use_exchange_rates
      # Convert all amounts to default currency
      @total_budget = 0
      @total_utilized = 0
      
      capex_for_year.each do |capex|
        converted_budget = helpers.convert_capex_currency(capex.total_amount, capex.currency, @default_currency, @current_year)
        converted_utilized = helpers.convert_capex_currency(capex.utilized_amount, capex.currency, @default_currency, @current_year)
        
        @total_budget += converted_budget
        @total_utilized += converted_utilized
      end
      
      @total_budget = @total_budget.round(2)
      @total_utilized = @total_utilized.round(2)
    else
      # Use original amounts without conversion
      @total_budget = capex_for_year.sum(:total_amount)
      @total_utilized = capex_for_year.sum { |c| c.utilized_amount }
    end
    
    @total_remaining = @total_budget - @total_utilized
    @utilization_percentage = @total_budget > 0 ? (@total_utilized / @total_budget * 100).round(2) : 0
    
    # Quarterly breakdown using unordered relation
    if @use_exchange_rates
      @quarterly_data = { q1: 0, q2: 0, q3: 0, q4: 0 }
      
      capex_for_year.each do |capex|
        @quarterly_data[:q1] += helpers.convert_capex_currency(capex.q1_amount, capex.currency, @default_currency, @current_year)
        @quarterly_data[:q2] += helpers.convert_capex_currency(capex.q2_amount, capex.currency, @default_currency, @current_year)
        @quarterly_data[:q3] += helpers.convert_capex_currency(capex.q3_amount, capex.currency, @default_currency, @current_year)
        @quarterly_data[:q4] += helpers.convert_capex_currency(capex.q4_amount, capex.currency, @default_currency, @current_year)
      end
      
      @quarterly_data.each { |k, v| @quarterly_data[k] = v.round(2) }
    else
      @quarterly_data = {
        q1: capex_for_year.sum(:q1_amount),
        q2: capex_for_year.sum(:q2_amount),
        q3: capex_for_year.sum(:q3_amount),
        q4: capex_for_year.sum(:q4_amount)
      }
    end
    
    # Currency breakdown using unordered relation
    @currency_breakdown = capex_for_year.group(:currency).sum(:total_amount)
    
    # TPC Code grouping - new functionality
    @tpc_grouping = {}
    capex_for_year.group_by(&:tpc_code).each do |tpc_code, entries|
      if @use_exchange_rates
        # Convert all amounts to default currency for TPC grouping
        total_budget = 0
        total_utilized = 0
        
        entries.each do |entry|
          total_budget += helpers.convert_capex_currency(entry.total_amount, entry.currency, @default_currency, @current_year)
          total_utilized += helpers.convert_capex_currency(entry.utilized_amount, entry.currency, @default_currency, @current_year)
        end
        
        total_budget = total_budget.round(2)
        total_utilized = total_utilized.round(2)
        currency_symbol = helpers.capex_currency_symbol(@default_currency)
      else
        # Use original amounts
        total_budget = entries.sum(&:total_amount)
        total_utilized = entries.sum(&:utilized_amount)
        
        # Get currency symbol (assuming all entries in same TPC use same currency for simplicity)
        first_entry = entries.first
        currency_symbol = first_entry ? first_entry.currency_symbol : '$'
      end
      
      utilization_percentage = total_budget > 0 ? (total_utilized / total_budget * 100).round(2) : 0
      
      @tpc_grouping[tpc_code] = {
        entries_count: entries.count,
        total_budget: total_budget,
        total_utilized: total_utilized,
        utilization_percentage: utilization_percentage,
        currency_symbol: currency_symbol
      }
    end
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          total_budget: @total_budget,
          total_utilized: @total_utilized,
          total_remaining: @total_remaining,
          utilization_percentage: @utilization_percentage,
          quarterly_data: @quarterly_data,
          currency_breakdown: @currency_breakdown,
          tpc_grouping: @tpc_grouping,
          use_exchange_rates: @use_exchange_rates,
          default_currency: @default_currency,
          capex_entries: @capex_entries.map do |capex|
            {
              id: capex.id,
              tpc_code: capex.tpc_code,
              description: capex.description,
              total_amount: capex.total_amount,
              utilized_amount: capex.utilized_amount,
              remaining_amount: capex.remaining_amount,
              utilization_percentage: capex.utilization_percentage,
              currency: capex.currency
            }
          end
        }
      end
    end
  end

  # New method to handle AJAX requests for dashboard data
  def dashboard_data
    @current_year = params[:year].present? ? params[:year].to_i : Date.current.year
    # Apply filters from params
    capex_for_year = @project.capex.for_year(@current_year)
    
    # Apply additional filters if present
    if params[:tpc_code].present?
      capex_for_year = capex_for_year.where(tpc_code: params[:tpc_code])
    end
    
    if params[:currency].present?
      capex_for_year = capex_for_year.where(currency: params[:currency])
    end
    
    # Get default currency for conversions
    @default_currency = helpers.default_capex_currency
    @use_exchange_rates = helpers.capex_use_exchange_rates?
    
    # Calculate summary statistics
    if @use_exchange_rates
      # Convert all amounts to default currency
      @total_budget = 0
      @total_utilized = 0
      
      capex_for_year.each do |capex|
        converted_budget = helpers.convert_capex_currency(capex.total_amount, capex.currency, @default_currency, @current_year)
        converted_utilized = helpers.convert_capex_currency(capex.utilized_amount, capex.currency, @default_currency, @current_year)
        
        @total_budget += converted_budget
        @total_utilized += converted_utilized
      end
      
      @total_budget = @total_budget.round(2)
      @total_utilized = @total_utilized.round(2)
    else
      # Use original amounts without conversion
      @total_budget = capex_for_year.sum(:total_amount)
      @total_utilized = capex_for_year.sum { |c| c.utilized_amount }
    end
    
    @total_remaining = @total_budget - @total_utilized
    @utilization_percentage = @total_budget > 0 ? (@total_utilized / @total_budget * 100).round(2) : 0
    
    # Quarterly breakdown
    if @use_exchange_rates
      @quarterly_data = { q1: 0, q2: 0, q3: 0, q4: 0 }
      
      capex_for_year.each do |capex|
        @quarterly_data[:q1] += helpers.convert_capex_currency(capex.q1_amount, capex.currency, @default_currency, @current_year)
        @quarterly_data[:q2] += helpers.convert_capex_currency(capex.q2_amount, capex.currency, @default_currency, @current_year)
        @quarterly_data[:q3] += helpers.convert_capex_currency(capex.q3_amount, capex.currency, @default_currency, @current_year)
        @quarterly_data[:q4] += helpers.convert_capex_currency(capex.q4_amount, capex.currency, @default_currency, @current_year)
      end
      
      @quarterly_data.each { |k, v| @quarterly_data[k] = v.round(2) }
    else
      @quarterly_data = {
        q1: capex_for_year.sum(:q1_amount),
        q2: capex_for_year.sum(:q2_amount),
        q3: capex_for_year.sum(:q3_amount),
        q4: capex_for_year.sum(:q4_amount)
      }
    end
    
    # Currency breakdown
    @currency_breakdown = capex_for_year.group(:currency).sum(:total_amount)
    
    # TPC Code grouping
    @tpc_grouping = {}
    capex_for_year.group_by(&:tpc_code).each do |tpc_code, entries|
      if @use_exchange_rates
        # Convert all amounts to default currency for TPC grouping
        total_budget = 0
        total_utilized = 0
        
        entries.each do |entry|
          total_budget += helpers.convert_capex_currency(entry.total_amount, entry.currency, @default_currency, @current_year)
          total_utilized += helpers.convert_capex_currency(entry.utilized_amount, entry.currency, @default_currency, @current_year)
        end
        
        total_budget = total_budget.round(2)
        total_utilized = total_utilized.round(2)
        currency_symbol = helpers.capex_currency_symbol(@default_currency)
      else
        # Use original amounts
        total_budget = entries.sum(&:total_amount)
        total_utilized = entries.sum(&:utilized_amount)
        
        # Get currency symbol (assuming all entries in same TPC use same currency for simplicity)
        first_entry = entries.first
        currency_symbol = first_entry ? first_entry.currency_symbol : '$'
      end
      
      utilization_percentage = total_budget > 0 ? (total_utilized / total_budget * 100).round(2) : 0
      
      @tpc_grouping[tpc_code] = {
        entries_count: entries.count,
        total_budget: total_budget,
        total_utilized: total_utilized,
        utilization_percentage: utilization_percentage,
        currency_symbol: currency_symbol
      }
    end
    
    render json: {
      total_budget: @total_budget,
      total_utilized: @total_utilized,
      total_remaining: @total_remaining,
      utilization_percentage: @utilization_percentage,
      quarterly_data: @quarterly_data,
      currency_breakdown: @currency_breakdown,
      tpc_grouping: @tpc_grouping,
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

  def find_capex
    @capex = @project.capex.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_capex_entries
    capex_entries = @project.capex.ordered
    
    if params[:search].present?
      capex_entries = capex_entries.search(params[:search])
    end
    
    capex_entries
  end

  def capex_params
    params.require(:capex).permit(:year, :description, :tpc_code, :tpc_code_id, :total_amount, 
                                  :currency, :q1_amount, :q2_amount, :q3_amount, 
                                  :q4_amount, :notes)
  end

  def check_quarterly_data_permission
    # Allow access if user can view purchase requests in this project
    unless User.current.allowed_to?(:view_purchase_requests, @project)
      render json: { error: 'Unauthorized' }, status: 403
      return false
    end
  end
end
