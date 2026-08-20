class CapexController < ApplicationController
  helper :sort
  include SortHelper
  include RedminePurchaseRequests::TpcFilterable
  before_action :find_project
  before_action :authorize, except: [:quarterly_data, :dashboard_data]
  before_action :find_capex, only: [:show, :edit, :update, :destroy]
  before_action :check_quarterly_data_permission, only: [:quarterly_data]
  skip_before_action :verify_authenticity_token, only: [:quarterly_data]
  
  menu_item :purchase_requests

  def index
    sort_init 'year', 'desc'
    sort_update %w[year tpc_code_id description total_amount]

    # Get years without ordering to avoid DISTINCT conflict
    @years = @project.capex.distinct.pluck(:year).sort.reverse
    @capex_entries = capex_index_scope.reorder(sort_clause)

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
    @available_tpc_codes = TpcCode.available_for_project(@project).active.ordered
    capex_for_year = apply_tpc_filter(capex_for_year)
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

  # Export the currently filtered CAPEX list as CSV.
  def export_csv
    scope = capex_index_scope
    send_data Capex.to_csv(scope),
              filename: capex_export_filename('csv'),
              type: 'text/csv',
              disposition: 'attachment'
  end

  # Export the currently filtered CAPEX list as XLSX.
  def export_xlsx
    scope = capex_index_scope
    send_data generate_capex_xlsx(scope),
              filename: capex_export_filename('xlsx'),
              type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              disposition: 'attachment'
  end

  # Export the currently filtered CAPEX list as PDF.
  def export_pdf
    scope = capex_index_scope
    send_data generate_capex_pdf(scope),
              filename: capex_export_filename('pdf'),
              type: 'application/pdf',
              disposition: 'attachment'
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

  # Filtered CAPEX scope shared by #index and the export actions, so an
  # export always matches what the current filters show on screen. Sets
  # @selected_year and @available_tpc_codes as a side effect (used by the
  # index view and by the export filenames).
  def capex_index_scope
    entries = find_capex_entries
    @selected_year = params[:year].present? ? params[:year].to_i : Date.current.year
    entries = entries.for_year(@selected_year) if @selected_year.present?

    @available_tpc_codes = TpcCode.available_for_project(@project).active.ordered
    apply_tpc_filter(entries)
  end

  def capex_export_filename(extension)
    parts = ['capex', @project.identifier]
    parts << @selected_year.to_s if @selected_year.present?
    parts << Date.current.strftime('%Y%m%d')
    "#{parts.join('_')}.#{extension}"
  end

  def generate_capex_xlsx(scope)
    require 'caxlsx'

    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: 'CAPEX') do |sheet|
      header_style = sheet.styles.add_style(b: true, bg_color: 'F4F3F9')
      sheet.add_row(
        ['Year', 'TPC Code', 'Description', 'Total Amount', 'Currency',
         'Q1 Amount', 'Q2 Amount', 'Q3 Amount', 'Q4 Amount',
         'Utilized', 'Remaining', 'Utilization %'],
        style: header_style
      )

      scope.includes(:tpc_code_record).each do |capex|
        sheet.add_row [
          capex.capex_year,
          capex.tpc_code_display,
          capex.description,
          capex.total_amount,
          capex.currency,
          capex.q1_amount,
          capex.q2_amount,
          capex.q3_amount,
          capex.q4_amount,
          capex.utilized_amount,
          capex.remaining_amount,
          capex.utilization_percentage
        ]
      end
    end

    package.to_stream.read
  end

  def generate_capex_pdf(scope)
    pdf = BrandedReportPdf.new(
      report_title:  'CAPEX Export',
      project:       @project,
      selected_year: @selected_year,
      orientation:   'L'
    )
    pdf.add_page
    pdf.print_cover(generated_at: Time.current, intro: 'CAPEX entries matching the current list filters.')
    pdf.section_heading('CAPEX Entries')

    header = ['Year', 'TPC Code', 'Description', 'Total Amount', 'Q1', 'Q2', 'Q3', 'Q4', 'Utilized', 'Remaining', 'Util %']
    rows = scope.includes(:tpc_code_record).map do |capex|
      [
        capex.capex_year,
        capex.tpc_code_display,
        capex.description.to_s.truncate(60),
        "#{capex.currency_symbol}#{helpers.number_with_precision(capex.total_amount, precision: 2, delimiter: ',')}",
        "#{capex.currency_symbol}#{helpers.number_with_precision(capex.q1_amount, precision: 0, delimiter: ',')}",
        "#{capex.currency_symbol}#{helpers.number_with_precision(capex.q2_amount, precision: 0, delimiter: ',')}",
        "#{capex.currency_symbol}#{helpers.number_with_precision(capex.q3_amount, precision: 0, delimiter: ',')}",
        "#{capex.currency_symbol}#{helpers.number_with_precision(capex.q4_amount, precision: 0, delimiter: ',')}",
        "#{capex.currency_symbol}#{helpers.number_with_precision(capex.utilized_amount, precision: 2, delimiter: ',')}",
        "#{capex.currency_symbol}#{helpers.number_with_precision(capex.remaining_amount, precision: 2, delimiter: ',')}",
        "#{capex.utilization_percentage.round(1)}%"
      ]
    end

    pdf.data_table(header, rows, col_widths: [14, 26, 55, 26, 20, 20, 20, 20, 24, 24, 12])
    pdf.output
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
