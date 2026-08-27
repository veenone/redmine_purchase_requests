class CapexController < ApplicationController
  include BudgetDashboard

  before_action :find_project
  before_action :authorize, except: [:quarterly_data]
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
    #
    # Deliberately kept free of .includes(:purchase_requests): this relation
    # feeds the `.sum(:column)`/`.group(...).sum(...)` SQL aggregates below
    # (quarterly totals and currency breakdown). Rails silently turns a SQL
    # SUM(:column) over a relation whose includes has-many association into
    # a LEFT OUTER JOIN, which multiplies an entry's amount by its
    # linked-request count. OPEX hit exactly that bug (see task-2-report.md)
    # when it merged its equivalent of this relation with the one carrying
    # .includes for view rendering. If a future change adds
    # .includes(:purchase_requests) here — e.g. to shave a query off some
    # new feature — re-verify every `.sum(:column)` call below against it
    # first.
    #
    # The headline totals (budget_dashboard_figures) and the TPC grouping
    # further down do NOT use this relation, on purpose: both enumerate
    # records in Ruby and call e.utilized_amount per record (an association
    # walk, not a SQL aggregate), so they use @capex_entries instead — see
    # the comment where it's assigned.
    capex_for_year = @project.capex.for_year(@current_year)
    @available_tpc_codes = TpcCode.available_for_project(@project).active.ordered
    @selected_tpc_code_id = params[:tpc_code_id].presence
    capex_for_year = capex_for_year.where(tpc_code_id: @selected_tpc_code_id) if @selected_tpc_code_id
    # utilized_amount enumerates linked requests per record, so preload them
    # once rather than issuing a query per row. This is the row set used by
    # budget_dashboard_figures, the TPC grouping below, and view rendering —
    # one preloaded load shared by all three, instead of the table being
    # queried once per consumer (kept separate from capex_for_year above
    # because that relation must stay preload-free — see its comment).
    @capex_entries = capex_for_year.ordered.includes(:purchase_requests)

    # Get default currency for conversions
    @default_currency = helpers.default_capex_currency
    @use_exchange_rates = helpers.capex_use_exchange_rates?

    # Calculate summary statistics using the preloaded relation — entries.to_a
    # plus Ruby-side sums, not a SQL aggregate, so the LEFT-OUTER-JOIN
    # double-count risk above doesn't apply here.
    figures = budget_dashboard_figures(
      @capex_entries,
      currency: @default_currency,
      convert: ->(amount, from) {
        @use_exchange_rates ? helpers.convert_capex_currency(amount, from, @default_currency, @current_year) : amount
      },
      missing_rate: (@use_exchange_rates ? ->(cur) { helpers.capex_missing_rate?(cur, @default_currency, @current_year) } : nil)
    )
    @total_budget            = figures[:total_budget]
    @total_utilized          = figures[:total_utilized]
    @total_remaining         = figures[:total_remaining]
    @utilization_percentage  = figures[:utilization_percentage]
    @currencies_mixed        = figures[:currencies_mixed]
    @unconvertible_currencies = figures[:unconvertible_currencies]
    @totals_unreliable       = figures[:totals_unreliable]
    @budget_over             = figures[:over_budget]
    @budget_severity         = figures[:severity]
    @budget_undefined        = figures[:budget_undefined]

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
    #
    # Grouped from @capex_entries (preloaded, identical row set to
    # capex_for_year), not capex_for_year: this loop calls entry.utilized_amount
    # per record, an association walk that would otherwise N+1 against an
    # un-preloaded relation.
    @tpc_grouping = {}
    @capex_entries.group_by(&:tpc_code).each do |tpc_code, entries|
      mixed_group = false
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
        
        # Without conversion, a group spanning currencies has no single symbol
        # and its total is a sum of unlike units — say so rather than stamping
        # the first entry's symbol on a number that isn't in that currency.
        group_currencies = entries.map { |e| e.currency.presence }.compact.uniq
        mixed_group = group_currencies.length > 1
        currency_symbol = mixed_group ? '' : (entries.first&.currency_symbol || '$')
      end
      
      utilization_percentage = total_budget > 0 ? (total_utilized / total_budget * 100).round(2) : 0

      @tpc_grouping[tpc_code] = {
        # Carried so the dashboard can link a card to its filtered view;
        # the grouping is keyed by code string but the filter takes an id.
        tpc_code_id: entries.first&.tpc_code_id,
        mixed_currency: mixed_group,
        entries_count: entries.count,
        total_budget: total_budget,
        total_utilized: total_utilized,
        utilization_percentage: utilization_percentage,
        # Spend with no budget behind it. utilization_percentage is 0 here
        # because the denominator is, which would render the group as a green
        # low-severity card. See BudgetDashboard#budget_dashboard_figures.
        budget_undefined: total_budget.to_f <= 0 && total_utilized.to_f > 0,
        currency_symbol: currency_symbol
      }
    end

    # Alphabetical is merely what group_by returned. The question this section
    # answers is "which codes are at risk", so the most at-risk lead — with
    # budget-less spend ahead of any percentage, since its ratio is undefined
    # rather than low (budget_group_rank).
    @tpc_grouping = @tpc_grouping.sort_by { |_code, d| budget_group_rank(d) }.to_h

    
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
