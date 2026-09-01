class ReportsController < ApplicationController
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::NumberHelper
  include PurchaseRequestsHelper

  before_action :find_optional_project
  before_action :authorize_reports
  before_action :set_year_filter

  # Main reports dashboard
  def index
    @available_reports = [
      {
        name: 'Purchase Requests Report',
        description: 'Comprehensive analysis of purchase requests including status, priorities, and financial metrics',
        action: 'purchase_requests',
        icon: 'icon-package'
      },
      {
        name: 'Vendors Report',
        description: 'Vendor analytics including activity, project associations, and performance metrics',
        action: 'vendors',
        icon: 'icon-group'
      },
      {
        name: 'TPC Codes Report',
        description: 'TPC code utilization and allocation across projects and budget items',
        action: 'tpc_codes',
        icon: 'icon-list'
      },
      {
        name: 'CAPEX Report',
        description: 'Capital expenditure analysis with quarterly breakdowns and budget tracking',
        action: 'capex',
        icon: 'icon-money'
      },
      {
        name: 'OPEX Report',
        description: 'Operational expenditure overview with category analysis and quarterly distribution',
        action: 'opex',
        icon: 'icon-stats'
      },
      {
        name: 'Executive Overview',
        description: 'High-level summary combining all features for executive reporting',
        action: 'overview',
        icon: 'icon-summary'
      }
    ]
  end
  
  # Purchase Requests Report
  def purchase_requests
    @report_data = generate_purchase_requests_report
    
    respond_to do |format|
      format.html
      format.pdf { 
        pdf_content = generate_pdf_report('Purchase Requests Report', @report_data)
        send_data pdf_content, 
                  filename: "purchase_requests_report_#{@project ? @project.identifier + '_' : ''}#{Date.current.strftime('%Y%m%d')}.pdf",
                  type: 'application/pdf',
                  disposition: 'inline'
      }
      format.docx { send_docx_report('Purchase Requests Report', 'purchase_requests_report') }
      format.csv { send_csv_data(@report_data[:csv_data], 'purchase_requests_report') }
      format.json { render json: @report_data }
    end
  end

  # Vendors Report
  def vendors
    @report_data = generate_vendors_report
    
    respond_to do |format|
      format.html
      format.pdf { 
        pdf_content = generate_pdf_report('Vendors Report', @report_data)
        send_data pdf_content, 
                  filename: "vendors_report_#{@project ? @project.identifier + '_' : ''}#{Date.current.strftime('%Y%m%d')}.pdf",
                  type: 'application/pdf',
                  disposition: 'inline'
      }
      format.docx { send_docx_report('Vendors Report', 'vendors_report') }
      format.csv { send_csv_data(@report_data[:csv_data], 'vendors_report') }
      format.json { render json: @report_data }
    end
  end

  # TPC Codes Report
  def tpc_codes
    @report_data = generate_tpc_codes_report
    
    respond_to do |format|
      format.html
      format.pdf { 
        pdf_content = generate_pdf_report('TPC Codes Report', @report_data)
        send_data pdf_content, 
                  filename: "tpc_codes_report_#{@project ? @project.identifier + '_' : ''}#{Date.current.strftime('%Y%m%d')}.pdf",
                  type: 'application/pdf',
                  disposition: 'inline'
      }
      format.docx { send_docx_report('TPC Codes Report', 'tpc_codes_report') }
      format.csv { send_csv_data(@report_data[:csv_data], 'tpc_codes_report') }
      format.json { render json: @report_data }
    end
  end

  # CAPEX Report
  def capex
    @report_data = generate_capex_report
    
    respond_to do |format|
      format.html
      format.pdf { 
        pdf_content = generate_pdf_report('CAPEX Report', @report_data)
        send_data pdf_content, 
                  filename: "capex_report_#{@project ? @project.identifier + '_' : ''}#{Date.current.strftime('%Y%m%d')}.pdf",
                  type: 'application/pdf',
                  disposition: 'inline'
      }
      format.docx { send_docx_report('CAPEX Report', 'capex_report') }
      format.csv { send_csv_data(@report_data[:csv_data], 'capex_report') }
      format.json { render json: @report_data }
    end
  end

  # OPEX Report
  def opex
    @report_data = generate_opex_report
    
    respond_to do |format|
      format.html
      format.pdf { 
        pdf_content = generate_pdf_report('OPEX Report', @report_data)
        send_data pdf_content, 
                  filename: "opex_report_#{@project ? @project.identifier + '_' : ''}#{Date.current.strftime('%Y%m%d')}.pdf",
                  type: 'application/pdf',
                  disposition: 'inline'
      }
      format.docx { send_docx_report('OPEX Report', 'opex_report') }
      format.csv { send_csv_data(@report_data[:csv_data], 'opex_report') }
      format.json { render json: @report_data }
    end
  end

  # Executive Overview Report
  def overview
    @report_data = generate_overview_report
    
    respond_to do |format|
      format.html
      format.pdf { 
        pdf_content = generate_pdf_report('Executive Overview Report', @report_data)
        send_data pdf_content, 
                  filename: "overview_report_#{@project ? @project.identifier + '_' : ''}#{Date.current.strftime('%Y%m%d')}.pdf",
                  type: 'application/pdf',
                  disposition: 'inline'
      }
      format.docx { send_docx_report('Executive Overview Report', 'executive_overview_report') }
      format.csv { send_csv_data(@report_data[:csv_data], 'executive_overview_report') }
      format.json { render json: @report_data }
    end
  end

  private

  # One-line cover intro per report type (shown under the cover title).
  def pdf_intro_for(title)
    {
      'Purchase Requests Report'  => 'Comprehensive analysis of purchase requests including status, priorities, budget sources, and financial metrics.',
      'Vendors Report'            => 'Vendor analytics including activity, project associations, and performance metrics.',
      'TPC Codes Report'          => 'TPC code utilization and allocation across projects and budget items.',
      'CAPEX Report'              => 'Capital expenditure analysis with quarterly breakdowns and budget tracking.',
      'OPEX Report'               => 'Operational expenditure overview with category analysis and quarterly distribution.',
      'Executive Overview Report' => 'High-level summary combining purchase, vendor, TPC, CAPEX, and OPEX data for executive reporting.'
    }[title]
  end

  # Render @report_data to DOCX via DocxReportHelper and stream it as an
  # attachment. If the OOXML stack ever fails to load, surface a friendly
  # error instead of crashing.
  def send_docx_report(title, filename_prefix)
    docx_blob = DocxReportHelper.generate(title, @report_data, project: @project, selected_year: @selected_year)
    send_data docx_blob,
              filename: "#{filename_prefix}_#{@project ? @project.identifier + '_' : ''}#{Date.current.strftime('%Y%m%d')}.docx",
              type: Mime[:docx].to_s,
              disposition: 'attachment'
  rescue LoadError => e
    Rails.logger.error("DOCX export unavailable: #{e.message}")
    flash[:error] = "DOCX export is unavailable. Install the caracal gem (`bundle install` from the Redmine root) and restart."
    redirect_back fallback_location: (@project ? project_reports_path(@project) : reports_path)
  end
  
  def find_optional_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def authorize_reports
    if @project
      # Project-specific reports
      unless User.current.allowed_to?(:view_purchase_request_reports, @project)
        deny_access
      end
    else
      # Global reports
      unless User.current.admin? || User.current.allowed_to?(:view_purchase_request_reports, nil, global: true)
        deny_access
      end
    end
  end

  # Year filter: defaults to the current year. Pass `year=` (empty) to
  # explicitly include all years. @available_years lists every year that
  # has any data across CAPEX, OPEX, and purchase requests.
  def set_year_filter
    if params.key?(:year)
      @selected_year = params[:year].to_s.strip
      @selected_year = nil if @selected_year.empty?
    else
      @selected_year = Date.current.year.to_s
    end

    capex_scope = @project ? @project.capex : Capex.all
    opex_scope  = @project ? @project.opex  : Opex.all
    pr_scope    = @project ? @project.purchase_requests : PurchaseRequest.all

    years = []
    years.concat(capex_scope.distinct.pluck(:year))
    years.concat(opex_scope.distinct.pluck(:year))

    pr_min = pr_scope.minimum(:created_at)
    pr_max = pr_scope.maximum(:created_at)
    if pr_min && pr_max
      (pr_min.year..pr_max.year).each { |y| years << y }
    end

    current_year = Date.current.year
    @available_years = (years + [current_year]).compact.map(&:to_i).uniq.sort.reverse
  end

  # Year window used by date-scoped reports (PRs, vendors, TPC, overview).
  def selected_year_range
    return nil if @selected_year.blank?
    year = @selected_year.to_i
    Date.new(year, 1, 1).beginning_of_day..Date.new(year, 12, 31).end_of_day
  end

  # Returns a scope filtered by the selected year, or the original scope
  # if no year is selected. `column` is the timestamp column to filter on
  # (defaults to :created_at).
  def scope_by_year(relation, column: :created_at)
    range = selected_year_range
    range ? relation.where(column => range) : relation
  end
  
  def generate_purchase_requests_report
    # Scope data based on project context
    purchase_requests = @project ? @project.purchase_requests : PurchaseRequest.all
    purchase_requests = purchase_requests.includes(:project, :status, :vendor, :user, :capex, :opex, :tpc_code)
    purchase_requests = scope_by_year(purchase_requests)

    # Basic statistics
    total_count = purchase_requests.count
    open_count = purchase_requests.joins(:status).where(purchase_request_statuses: { is_closed: false }).count
    closed_count = purchase_requests.joins(:status).where(purchase_request_statuses: { is_closed: true }).count

    # Status breakdown
    status_breakdown = purchase_requests.joins(:status)
                                       .group('purchase_request_statuses.name')
                                       .count

    # Priority distribution
    priority_breakdown = purchase_requests.group(:priority).count

    # Financial summary
    total_estimated_value = PurchaseRequest.committed_sum(purchase_requests)
    avg_estimated_value = purchase_requests.where.not(estimated_price: nil).average(:estimated_price)

    # Monthly trend (last 12 months)
    monthly_trend = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = month_start.end_of_month
      count = purchase_requests.where(created_at: month_start..month_end).count
      monthly_trend[month_start] = count
    end
    monthly_trend = monthly_trend.sort.to_h

    # Top vendors
    vendor_stats = purchase_requests.joins(:vendor)
                                   .group('vendors.name')
                                   .group('vendors.id')
                                   .count
                                   .sort_by { |_, count| -count }
                                   .first(10)

    # Budget source breakdown (CAPEX, OPEX, Direct TPC, Non-budgeted)
    capex_count = purchase_requests.where.not(capex_id: nil).count
    opex_count = purchase_requests.where.not(opex_id: nil).count
    direct_tpc_count = purchase_requests.where(capex_id: nil, opex_id: nil).where.not(tpc_code_id: nil).count
    non_budgeted_count = purchase_requests.where(capex_id: nil, opex_id: nil, tpc_code_id: nil).count

    budget_source_breakdown = {
      'CAPEX' => capex_count,
      'OPEX' => opex_count,
      'Direct TPC' => direct_tpc_count,
      'Non-budgeted' => non_budgeted_count
    }

    # Budget source by value
    capex_value = PurchaseRequest.committed_sum(purchase_requests.where.not(capex_id: nil))
    opex_value = PurchaseRequest.committed_sum(purchase_requests.where.not(opex_id: nil))
    direct_tpc_value = PurchaseRequest.committed_sum(purchase_requests.where(capex_id: nil, opex_id: nil).where.not(tpc_code_id: nil))
    non_budgeted_value = PurchaseRequest.committed_sum(purchase_requests.where(capex_id: nil, opex_id: nil, tpc_code_id: nil))

    budget_source_value = {
      'CAPEX' => capex_value || 0,
      'OPEX' => opex_value || 0,
      'Direct TPC' => direct_tpc_value || 0,
      'Non-budgeted' => non_budgeted_value || 0
    }

    # Requester breakdown (top 10)
    requester_breakdown = purchase_requests.joins(:user)
                                           .group('users.id', 'users.firstname', 'users.lastname')
                                           .count
                                           .sort_by { |_, count| -count }
                                           .first(10)
                                           .map { |k, v| { id: k[0], name: "#{k[1]} #{k[2]}", count: v } }

    # TPC code distribution (top 10)
    tpc_distribution = {}

    # Direct TPC assignments
    direct_tpc = purchase_requests.joins(:tpc_code)
                                  .group('tpc_codes.tpc_number')
                                  .count

    # Via CAPEX
    capex_tpc = purchase_requests.joins(capex: :tpc_code_record)
                                 .group('tpc_codes.tpc_number')
                                 .count

    # Via OPEX
    opex_tpc = purchase_requests.joins(opex: :tpc_code)
                                .group('tpc_codes.tpc_number')
                                .count

    # Merge all TPC counts
    [direct_tpc, capex_tpc, opex_tpc].each do |tpc_hash|
      tpc_hash.each do |tpc_number, count|
        tpc_distribution[tpc_number] = (tpc_distribution[tpc_number] || 0) + count
      end
    end
    tpc_distribution = tpc_distribution.sort_by { |_, count| -count }.first(10).to_h

    # TPC value distribution
    tpc_value_distribution = {}

    direct_tpc_values = purchase_requests.joins(:tpc_code)
                                         .where.not(estimated_price: nil)
                                         .group('tpc_codes.tpc_number')
                                         .budgeted.sum(:estimated_price)

    capex_tpc_values = purchase_requests.joins(capex: :tpc_code_record)
                                        .where.not(estimated_price: nil)
                                        .group('tpc_codes.tpc_number')
                                        .budgeted.sum(:estimated_price)

    opex_tpc_values = purchase_requests.joins(opex: :tpc_code)
                                       .where.not(estimated_price: nil)
                                       .group('tpc_codes.tpc_number')
                                       .budgeted.sum(:estimated_price)

    [direct_tpc_values, capex_tpc_values, opex_tpc_values].each do |tpc_hash|
      tpc_hash.each do |tpc_number, value|
        tpc_value_distribution[tpc_number] = (tpc_value_distribution[tpc_number] || 0) + value.to_f
      end
    end
    tpc_value_distribution = tpc_value_distribution.sort_by { |_, value| -value }.first(10).to_h

    # Monthly cost consumption trend (last 12 months)
    monthly_cost_trend = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = month_start.end_of_month
      value = PurchaseRequest.committed_sum(purchase_requests.where(created_at: month_start..month_end))
      monthly_cost_trend[month_start.strftime('%b %Y')] = value || 0
    end
    monthly_cost_trend = monthly_cost_trend.to_a.reverse.to_h

    # Generate CSV data
    csv_data = generate_purchase_requests_csv(purchase_requests)

    {
      summary: {
        total_count: total_count,
        open_count: open_count,
        closed_count: closed_count,
        total_estimated_value: total_estimated_value || 0,
        avg_estimated_value: avg_estimated_value || 0,
        capex_count: capex_count,
        opex_count: opex_count,
        direct_tpc_count: direct_tpc_count,
        non_budgeted_count: non_budgeted_count
      },
      status_breakdown: status_breakdown,
      priority_breakdown: priority_breakdown,
      monthly_trend: monthly_trend,
      monthly_cost_trend: monthly_cost_trend,
      vendor_stats: vendor_stats,
      budget_source_breakdown: budget_source_breakdown,
      budget_source_value: budget_source_value,
      requester_breakdown: requester_breakdown,
      tpc_distribution: tpc_distribution,
      tpc_value_distribution: tpc_value_distribution,
      recent_requests: purchase_requests.order(created_at: :desc).limit(10),
      csv_data: csv_data,
      project: @project,
      generated_at: Time.current
    }
  end
  
  def generate_vendors_report
    # Scope data based on project context
    base_vendors = @project ? Vendor.available_for_project(@project) : Vendor.all

    # Year filter: restrict to vendors that have at least one PR in the year
    if (range = selected_year_range)
      year_pr_scope = (@project ? @project.purchase_requests : PurchaseRequest.all).where(created_at: range)
      vendor_ids_with_activity = year_pr_scope.where.not(vendor_id: nil).distinct.pluck(:vendor_id)
      base_vendors = base_vendors.where(id: vendor_ids_with_activity)
    end

    # Basic statistics (avoid includes for simple counts)
    total_count = base_vendors.count
    active_count = base_vendors.active.count
    inactive_count = total_count - active_count
    global_count = base_vendors.global.count
    project_specific_count = base_vendors.where.not('vendors.project_id' => nil).count

    # Purchase request associations (avoid ambiguous project_id)
    vendors_with_requests = base_vendors.joins(:purchase_requests).distinct.count
    vendors_without_requests = total_count - vendors_with_requests

    # Activity analysis - top vendors by purchase request count
    vendor_activity = base_vendors.left_joins(:purchase_requests)
                                 .group('vendors.id', 'vendors.name')
                                 .count('purchase_requests.id')
                                 .sort_by { |_, count| -count }

    # Top vendors by total value
    vendor_by_value = base_vendors.joins(:purchase_requests)
                                  .where.not(purchase_requests: { estimated_price: nil })
                                  .group('vendors.id', 'vendors.name')
                                  .sum('purchase_requests.estimated_price')
                                  .sort_by { |_, value| -value }
                                  .first(10)

    # Include associations for final vendor list
    vendors = base_vendors.includes(:purchase_requests, :project)

    # Project distribution (for global view)
    if @project.nil?
      project_distribution = base_vendors.where.not('vendors.project_id' => nil)
                                        .joins(:project)
                                        .group('projects.name')
                                        .count
    end

    # Monthly vendor creation trend (last 12 months)
    monthly_vendor_trend = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = month_start.end_of_month
      count = base_vendors.where(created_at: month_start..month_end).count
      monthly_vendor_trend[month_start.strftime('%b %Y')] = count
    end
    monthly_vendor_trend = monthly_vendor_trend.to_a.reverse.to_h

    # Monthly purchase request trend by vendor engagement
    monthly_pr_trend = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = month_start.end_of_month
      pr_scope = @project ? @project.purchase_requests : PurchaseRequest.all
      count = pr_scope.where(created_at: month_start..month_end).where.not(vendor_id: nil).count
      monthly_pr_trend[month_start.strftime('%b %Y')] = count
    end
    monthly_pr_trend = monthly_pr_trend.to_a.reverse.to_h

    # Generate CSV data
    csv_data = generate_vendors_csv(vendors)

    {
      summary: {
        total_count: total_count,
        active_count: active_count,
        inactive_count: inactive_count,
        global_count: global_count,
        project_specific_count: project_specific_count,
        vendors_with_requests: vendors_with_requests,
        vendors_without_requests: vendors_without_requests
      },
      vendor_activity: vendor_activity.first(15),
      vendor_by_value: vendor_by_value,
      monthly_vendor_trend: monthly_vendor_trend,
      monthly_pr_trend: monthly_pr_trend,
      project_distribution: (project_distribution if @project.nil?),
      recent_vendors: vendors.order(created_at: :desc).limit(10),
      csv_data: csv_data,
      project: @project,
      generated_at: Time.current
    }
  end
  
  def generate_tpc_codes_report
    # Scope data based on project context
    tpc_codes = @project ? TpcCode.available_for_project(@project) : TpcCode.all
    tpc_codes = tpc_codes.includes(:capex, :opex, :project, :purchase_requests)

    # Purchase request base scope
    pr_base_scope = @project ? @project.purchase_requests : PurchaseRequest.all
    pr_base_scope = scope_by_year(pr_base_scope)

    # Year filter: restrict to TPC codes with PR activity in the year
    if @selected_year.present?
      active_tpc_ids = pr_base_scope.where.not(tpc_code_id: nil).distinct.pluck(:tpc_code_id)
      active_tpc_ids.concat(pr_base_scope.joins(:capex).where.not(capex: { tpc_code_id: nil }).distinct.pluck('capex.tpc_code_id'))
      active_tpc_ids.concat(pr_base_scope.joins(:opex).where.not(opex: { tpc_code_id: nil }).distinct.pluck('opex.tpc_code_id'))
      tpc_codes = tpc_codes.where(id: active_tpc_ids.uniq.compact)
    end

    # Basic statistics
    total_count = tpc_codes.count
    active_count = tpc_codes.active.count
    inactive_count = tpc_codes.inactive.count
    global_count = tpc_codes.global.count

    # Department breakdown
    department_breakdown = tpc_codes.joins(:department).group('departments.name').count

    # Usage analysis
    capex_usage = tpc_codes.joins(:capex).group('tpc_codes.tpc_number').count
    opex_usage = tpc_codes.joins(:opex).group('tpc_codes.tpc_number').count
    direct_pr_usage = tpc_codes.joins(:purchase_requests).group('tpc_codes.tpc_number').count

    # Financial allocation from budget entries
    capex_totals = tpc_codes.joins(:capex)
                            .group('tpc_codes.tpc_number')
                            .sum('capex.total_amount')

    opex_totals = tpc_codes.joins(:opex)
                           .group('tpc_codes.tpc_number')
                           .sum('opex.total_amount')

    # Purchase request counts by TPC code (from all sources)
    tpc_pr_counts = {}
    default_currency = Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'

    # Count direct TPC assignments
    direct_tpc_counts = pr_base_scope.where.not(tpc_code_id: nil).group(:tpc_code_id).count
    direct_tpc_counts.each { |tpc_id, count| tpc_pr_counts[tpc_id] = (tpc_pr_counts[tpc_id] || 0) + count }

    # Count via CAPEX
    capex_tpc_counts = pr_base_scope.joins(:capex).where.not(capex: { tpc_code_id: nil }).group('capex.tpc_code_id').count
    capex_tpc_counts.each { |tpc_id, count| tpc_pr_counts[tpc_id] = (tpc_pr_counts[tpc_id] || 0) + count }

    # Count via OPEX
    opex_tpc_counts = pr_base_scope.joins(:opex).where.not(opex: { tpc_code_id: nil }).group('opex.tpc_code_id').count
    opex_tpc_counts.each { |tpc_id, count| tpc_pr_counts[tpc_id] = (tpc_pr_counts[tpc_id] || 0) + count }

    # Build TPC by purchase request data
    tpc_by_purchase_request = []
    tpc_pr_counts.each do |tpc_id, count|
      tpc = TpcCode.find_by(id: tpc_id)
      next unless tpc
      tpc_by_purchase_request << {
        tpc_number: tpc.tpc_number,
        department: tpc.department&.name,
        owner: tpc.tpc_owner_name,
        count: count
      }
    end
    tpc_by_purchase_request = tpc_by_purchase_request.sort_by { |t| -t[:count] }.take(10)

    # Calculate total cost utilization per TPC code
    tpc_utilization = []
    tpc_codes.active.limit(20).each do |tpc|
      total_cost = 0
      request_count = 0
      capex_count = 0
      opex_count = 0
      direct_count = 0

      # Get costs from CAPEX entries
      capex_scope = @project ? tpc.capex.where(project_id: @project.id) : tpc.capex
      capex_scope.each do |capex|
        capex.purchase_requests.each do |pr|
          curr = pr.currency.presence || default_currency
          total_cost += convert_currency_for_report(pr.estimated_price || 0, curr, default_currency)
          request_count += 1
          capex_count += 1
        end
      end

      # Get costs from OPEX entries
      opex_scope = @project ? tpc.opex.where(project_id: @project.id) : tpc.opex
      opex_scope.each do |opex|
        opex.purchase_requests.each do |pr|
          curr = pr.currency.presence || default_currency
          total_cost += convert_currency_for_report(pr.estimated_price || 0, curr, default_currency)
          request_count += 1
          opex_count += 1
        end
      end

      # Get costs from direct purchase requests
      pr_scope = @project ? tpc.purchase_requests.where(project_id: @project.id) : tpc.purchase_requests
      pr_scope.where.not(estimated_price: nil).each do |pr|
        curr = pr.currency.presence || default_currency
        total_cost += convert_currency_for_report(pr.estimated_price, curr, default_currency)
        request_count += 1
        direct_count += 1
      end

      next if request_count == 0

      tpc_utilization << {
        tpc_code: tpc.tpc_number,
        tpc_name: tpc.tpc_name.to_s,
        department: tpc.department&.name,
        owner: tpc.tpc_owner_name,
        total_cost: total_cost.round(2),
        request_count: request_count,
        capex_count: capex_count,
        opex_count: opex_count,
        direct_count: direct_count
      }
    end
    tpc_utilization = tpc_utilization.sort_by { |t| -t[:total_cost] }.take(10)

    # Non-budgeted purchase requests (no CAPEX, OPEX, or direct TPC)
    non_budgeted_count = pr_base_scope.where(capex_id: nil, opex_id: nil, tpc_code_id: nil).count
    non_budgeted_value = PurchaseRequest.committed_sum(pr_base_scope.where(capex_id: nil, opex_id: nil, tpc_code_id: nil))

    # Monthly trend (last 12 months)
    monthly_trend = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = month_start.end_of_month

      # Count PRs with TPC codes in this month
      month_pr_scope = pr_base_scope.where(created_at: month_start..month_end)
      direct = month_pr_scope.where.not(tpc_code_id: nil).count
      via_capex = month_pr_scope.joins(:capex).where.not(capex: { tpc_code_id: nil }).count
      via_opex = month_pr_scope.joins(:opex).where.not(opex: { tpc_code_id: nil }).count

      monthly_trend[month_start] = direct + via_capex + via_opex
    end
    monthly_trend = monthly_trend.sort.to_h

    # Generate CSV data
    csv_data = generate_tpc_codes_csv(tpc_codes)

    {
      summary: {
        total_count: total_count,
        active_count: active_count,
        inactive_count: inactive_count,
        global_count: global_count,
        with_capex: capex_usage.count,
        with_opex: opex_usage.count,
        with_direct_pr: direct_pr_usage.count,
        non_budgeted_count: non_budgeted_count,
        non_budgeted_value: non_budgeted_value || 0
      },
      department_breakdown: department_breakdown,
      capex_usage: capex_usage,
      opex_usage: opex_usage,
      direct_pr_usage: direct_pr_usage,
      capex_totals: capex_totals,
      opex_totals: opex_totals,
      tpc_by_purchase_request: tpc_by_purchase_request,
      tpc_utilization: tpc_utilization,
      monthly_trend: monthly_trend,
      recent_codes: tpc_codes.order(created_at: :desc).limit(10),
      csv_data: csv_data,
      project: @project,
      generated_at: Time.current
    }
  end

  # Helper method for currency conversion in reports
  def convert_currency_for_report(amount, from_currency, to_currency)
    return amount if from_currency == to_currency || amount.nil? || amount == 0

    settings = Setting.plugin_redmine_purchase_requests
    exchange_rates = settings['exchange_rates'] || {}

    rate = exchange_rates[from_currency].to_f
    return amount if rate <= 0

    (amount / rate).round(2)
  end
  
  def generate_capex_report
    # Scope data based on project context
    capex_items = @project ? @project.capex : Capex.all
    capex_items = capex_items.includes(:project, :tpc_code_record, :purchase_requests)
    capex_items = capex_items.for_year(@selected_year) if @selected_year.present?

    # Year-based analysis
    current_year = Date.current.year
    years = capex_items.distinct.pluck(:year).sort

    # Financial summary by year
    yearly_totals = capex_items.group(:year).sum(:total_amount)

    # Quarterly breakdown for current year
    current_year_items = capex_items.for_year(current_year)
    quarterly_breakdown = {
      q1: current_year_items.sum(:q1_amount),
      q2: current_year_items.sum(:q2_amount),
      q3: current_year_items.sum(:q3_amount),
      q4: current_year_items.sum(:q4_amount)
    }

    # TPC code distribution
    tpc_distribution_raw = capex_items.joins(:tpc_code_record)
                                     .group('tpc_codes.tpc_number')
                                     .sum(:total_amount)
    tpc_distribution = tpc_distribution_raw.sort_by { |_, amount| -amount }

    # Currency analysis
    currency_breakdown = capex_items.group(:currency).sum(:total_amount)

    # Utilization status breakdown
    capex_with_pr = capex_items.joins(:purchase_requests).distinct.count
    capex_without_pr = capex_items.count - capex_with_pr

    utilization_breakdown = {
      'With Purchase Requests' => capex_with_pr,
      'Without Purchase Requests' => capex_without_pr
    }

    # Calculate utilization percentage (spent vs budgeted)
    utilization_details = []
    capex_items.includes(:purchase_requests).each do |capex|
      next if capex.total_amount.nil? || capex.total_amount == 0

      spent = PurchaseRequest.committed_sum(capex.purchase_requests)
      budgeted = capex.total_amount
      utilization_pct = (spent.to_f / budgeted * 100).round(1)

      status = if utilization_pct >= 100
                 'over_budget'
               elsif utilization_pct >= 75
                 'high_utilization'
               elsif utilization_pct >= 50
                 'medium_utilization'
               elsif utilization_pct > 0
                 'low_utilization'
               else
                 'unused'
               end

      utilization_details << {
        id: capex.id,
        description: capex.description,
        year: capex.year,
        budgeted: budgeted,
        spent: spent,
        remaining: budgeted - spent,
        utilization_pct: utilization_pct,
        status: status,
        pr_count: capex.purchase_requests.count
      }
    end

    # Utilization status summary
    utilization_status_breakdown = {
      'Over Budget (100%+)' => utilization_details.count { |u| u[:status] == 'over_budget' },
      'High (75-99%)' => utilization_details.count { |u| u[:status] == 'high_utilization' },
      'Medium (50-74%)' => utilization_details.count { |u| u[:status] == 'medium_utilization' },
      'Low (1-49%)' => utilization_details.count { |u| u[:status] == 'low_utilization' },
      'Unused (0%)' => utilization_details.count { |u| u[:status] == 'unused' }
    }

    # Top utilized CAPEX items
    top_utilized = utilization_details.sort_by { |u| -u[:utilization_pct] }.first(10)

    # Purchase request status breakdown for CAPEX-linked PRs
    pr_status_breakdown = {}
    capex_items.each do |capex|
      capex.purchase_requests.joins(:status).group('purchase_request_statuses.name').count.each do |status, count|
        pr_status_breakdown[status] = (pr_status_breakdown[status] || 0) + count
      end
    end

    # Total PRs linked to CAPEX
    total_capex_prs = capex_items.joins(:purchase_requests).count
    total_capex_pr_value = capex_items.joins(:purchase_requests)
                                      .where.not(purchase_requests: { estimated_price: nil })
                                      .sum('purchase_requests.estimated_price')

    # Generate CSV data
    csv_data = generate_capex_csv(capex_items)

    {
      summary: {
        total_items: capex_items.count,
        total_value: yearly_totals.values.sum,
        years_covered: years,
        current_year_value: yearly_totals[current_year] || 0,
        capex_with_pr: capex_with_pr,
        capex_without_pr: capex_without_pr,
        total_capex_prs: total_capex_prs,
        total_capex_pr_value: total_capex_pr_value || 0
      },
      yearly_totals: yearly_totals,
      quarterly_breakdown: quarterly_breakdown,
      tpc_distribution: tpc_distribution.first(10),
      currency_breakdown: currency_breakdown,
      utilization_breakdown: utilization_breakdown,
      utilization_status_breakdown: utilization_status_breakdown,
      top_utilized: top_utilized,
      pr_status_breakdown: pr_status_breakdown,
      recent_items: capex_items.order(created_at: :desc).limit(10),
      csv_data: csv_data,
      project: @project,
      generated_at: Time.current
    }
  end
  
  def generate_opex_report
    # Scope data based on project context
    opex_items = @project ? @project.opex : Opex.all
    opex_items = opex_items.includes(:project, :tpc_code, :opex_category, :purchase_requests)
    opex_items = opex_items.for_year(@selected_year) if @selected_year.present?
    
    # Year-based analysis
    current_year = Date.current.year
    years = opex_items.distinct.pluck(:year).sort
    
    # Financial summary by year
    yearly_totals = opex_items.group(:year).sum(:total_amount)
    
    # Quarterly breakdown for current year
    current_year_items = opex_items.for_year(current_year)
    quarterly_breakdown = {
      q1: current_year_items.sum(:q1_amount),
      q2: current_year_items.sum(:q2_amount),
      q3: current_year_items.sum(:q3_amount),
      q4: current_year_items.sum(:q4_amount)
    }
    
    # Category analysis
    category_breakdown_raw = opex_items.joins(:opex_category)
                                      .group('opex_categories.name')
                                      .sum(:total_amount)
    category_breakdown = category_breakdown_raw.sort_by { |_, amount| -amount }.to_h
    
    # TPC code distribution
    tpc_distribution_raw = opex_items.joins(:tpc_code)
                                    .group('tpc_codes.tpc_number')
                                    .sum(:total_amount)
    tpc_distribution = tpc_distribution_raw.sort_by { |_, amount| -amount }
    
    # Currency analysis
    currency_breakdown = opex_items.group(:currency).sum(:total_amount)
    
    # Generate CSV data
    csv_data = generate_opex_csv(opex_items)
    
    {
      summary: {
        total_items: opex_items.count,
        total_value: yearly_totals.values.sum,
        years_covered: years,
        current_year_value: yearly_totals[current_year] || 0
      },
      yearly_totals: yearly_totals,
      quarterly_breakdown: quarterly_breakdown,
      category_breakdown: category_breakdown,
      tpc_distribution: tpc_distribution.first(10),
      currency_breakdown: currency_breakdown,
      recent_items: opex_items.order(created_at: :desc).limit(10),
      csv_data: csv_data,
      project: @project,
      generated_at: Time.current
    }
  end
  
  def generate_overview_report
    # Generate all individual reports
    pr_data = generate_purchase_requests_report
    vendor_data = generate_vendors_report
    tpc_data = generate_tpc_codes_report
    capex_data = generate_capex_report
    opex_data = generate_opex_report

    # Executive summary combining all data
    executive_summary = {
      purchase_requests: {
        total: pr_data[:summary][:total_count],
        open: pr_data[:summary][:open_count],
        closed: pr_data[:summary][:closed_count],
        total_value: pr_data[:summary][:total_estimated_value],
        avg_value: pr_data[:summary][:avg_estimated_value]
      },
      vendors: {
        total: vendor_data[:summary][:total_count],
        active: vendor_data[:summary][:active_count],
        with_requests: vendor_data[:summary][:vendors_with_requests]
      },
      tpc_codes: {
        total: tpc_data[:summary][:total_count],
        active: tpc_data[:summary][:active_count]
      },
      capex: {
        total_items: capex_data[:summary][:total_items],
        total_value: capex_data[:summary][:total_value]
      },
      opex: {
        total_items: opex_data[:summary][:total_items],
        total_value: opex_data[:summary][:total_value]
      }
    }

    # Combined financial overview
    total_budget = capex_data[:summary][:total_value] + opex_data[:summary][:total_value]

    # Budget distribution including non-budgeted purchases
    budget_distribution = generate_budget_distribution_data(pr_data)

    # Currency usage analysis
    currency_usage = generate_currency_usage_data

    # Vendor country distribution
    vendor_countries = generate_vendor_country_data

    # Additional high-level indicators
    high_level_indicators = generate_high_level_indicators(pr_data, vendor_data, capex_data, opex_data)

    # Generate combined CSV
    csv_data = generate_overview_csv(pr_data, vendor_data, tpc_data, capex_data, opex_data)

    {
      executive_summary: executive_summary,
      total_budget: total_budget,
      budget_distribution: budget_distribution,
      currency_usage: currency_usage,
      vendor_countries: vendor_countries,
      high_level_indicators: high_level_indicators,
      purchase_requests: pr_data,
      vendors: vendor_data,
      tpc_codes: tpc_data,
      capex: capex_data,
      opex: opex_data,
      csv_data: csv_data,
      project: @project,
      generated_at: Time.current
    }
  end

  def generate_budget_distribution_data(pr_data)
    # Get budget source values including non-budgeted
    {
      'CAPEX' => pr_data[:budget_source_value]['CAPEX'] || 0,
      'OPEX' => pr_data[:budget_source_value]['OPEX'] || 0,
      'Direct TPC' => pr_data[:budget_source_value]['Direct TPC'] || 0,
      'Non-budgeted' => pr_data[:budget_source_value]['Non-budgeted'] || 0
    }
  end

  def generate_currency_usage_data
    purchase_requests = @project ? @project.purchase_requests : PurchaseRequest.all

    # Currency breakdown by count
    currency_by_count = purchase_requests.where.not(currency: [nil, ''])
                                         .group(:currency)
                                         .count

    # Currency breakdown by value
    currency_by_value = purchase_requests.where.not(currency: [nil, ''])
                                         .where.not(estimated_price: nil)
                                         .group(:currency)
                                         .budgeted.sum(:estimated_price)

    {
      by_count: currency_by_count,
      by_value: currency_by_value
    }
  end

  def generate_vendor_country_data
    base_vendors = @project ? Vendor.available_for_project(@project) : Vendor.all

    # Country distribution - handle potential missing country column gracefully
    country_distribution = {}
    if base_vendors.column_names.include?('country')
      country_distribution = base_vendors.where.not(country: [nil, ''])
                                         .group(:country)
                                         .count
                                         .sort_by { |_, count| -count }
                                         .to_h
    end

    # Add vendors without country
    vendors_without_country = base_vendors.where(country: [nil, '']).count

    {
      distribution: country_distribution,
      without_country: vendors_without_country,
      total_countries: country_distribution.keys.count
    }
  end

  def generate_high_level_indicators(pr_data, vendor_data, capex_data, opex_data)
    purchase_requests = @project ? @project.purchase_requests : PurchaseRequest.all

    # Completion rate
    total_prs = pr_data[:summary][:total_count]
    closed_prs = pr_data[:summary][:closed_count]
    completion_rate = total_prs > 0 ? ((closed_prs.to_f / total_prs) * 100).round(1) : 0

    # Average processing time (days from created to closed)
    closed_requests = purchase_requests.joins(:status).where(purchase_request_statuses: { is_closed: true })
    avg_processing_days = 0
    if closed_requests.any?
      total_days = closed_requests.sum { |pr| (pr.updated_at.to_date - pr.created_at.to_date).to_i }
      avg_processing_days = (total_days.to_f / closed_requests.count).round(1)
    end

    # This month's activity
    this_month_start = Date.current.beginning_of_month
    this_month_prs = purchase_requests.where('created_at >= ?', this_month_start).count
    this_month_value = PurchaseRequest.committed_sum(purchase_requests.where('created_at >= ?', this_month_start))

    # Last month comparison
    last_month_start = 1.month.ago.beginning_of_month
    last_month_end = 1.month.ago.end_of_month
    last_month_prs = purchase_requests.where(created_at: last_month_start..last_month_end).count

    # Month-over-month growth
    mom_growth = last_month_prs > 0 ? (((this_month_prs - last_month_prs).to_f / last_month_prs) * 100).round(1) : 0

    # Budget utilization (PR value vs total budget)
    total_budget = (capex_data[:summary][:total_value] || 0) + (opex_data[:summary][:total_value] || 0)
    total_pr_value = pr_data[:summary][:total_estimated_value] || 0
    budget_utilization = total_budget > 0 ? ((total_pr_value / total_budget) * 100).round(1) : 0

    # Top priority distribution
    high_priority_count = purchase_requests.where(priority: ['high', 'urgent', 'critical']).count
    high_priority_pct = total_prs > 0 ? ((high_priority_count.to_f / total_prs) * 100).round(1) : 0

    # Vendor engagement rate
    vendor_engagement = vendor_data[:summary][:total_count] > 0 ?
      ((vendor_data[:summary][:vendors_with_requests].to_f / vendor_data[:summary][:total_count]) * 100).round(1) : 0

    {
      completion_rate: completion_rate,
      avg_processing_days: avg_processing_days,
      this_month_prs: this_month_prs,
      this_month_value: this_month_value,
      mom_growth: mom_growth,
      budget_utilization: budget_utilization,
      high_priority_count: high_priority_count,
      high_priority_pct: high_priority_pct,
      vendor_engagement: vendor_engagement,
      total_budget: total_budget
    }
  end
  
  # CSV generation methods
  def generate_purchase_requests_csv(purchase_requests)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      # Report metadata header
      csv << ['Report', 'Purchase Requests Report']
      csv << ['Generated By', "#{User.current.name} (#{User.current.mail})"]
      csv << ['Generated At', Time.current.strftime('%Y-%m-%d %H:%M:%S')]
      csv << ['Project', @project ? @project.name : 'All Projects']
      csv << []  # Empty row separator

      csv << ['ID', 'Title', 'Project', 'Status', 'Priority', 'Vendor', 'Vendor Country', 'Estimated Price', 'Currency', 'Budget Source', 'TPC Code', 'Requester', 'Created', 'Due Date', 'Updated']

      purchase_requests.each do |pr|
        # Determine budget source
        budget_source = if pr.capex_id.present?
                          'CAPEX'
                        elsif pr.opex_id.present?
                          'OPEX'
                        elsif pr.tpc_code_id.present?
                          'Direct TPC'
                        else
                          'Non-budgeted'
                        end

        # Get TPC code
        tpc_code = pr.capex&.tpc_code_record&.tpc_number || pr.opex&.tpc_code&.tpc_number || pr.tpc_code&.tpc_number

        csv << [
          pr.id,
          pr.title,
          pr.project&.name,
          pr.status&.name,
          pr.priority,
          pr.vendor&.name,
          pr.vendor&.respond_to?(:country) ? pr.vendor&.country : '',
          pr.estimated_price,
          pr.currency,
          budget_source,
          tpc_code,
          pr.user&.name,
          pr.created_at&.strftime('%Y-%m-%d'),
          pr.due_date&.strftime('%Y-%m-%d'),
          pr.updated_at&.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_vendors_csv(vendors)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      # Report metadata header
      csv << ['Report', 'Vendors Report']
      csv << ['Generated By', "#{User.current.name} (#{User.current.mail})"]
      csv << ['Generated At', Time.current.strftime('%Y-%m-%d %H:%M:%S')]
      csv << ['Project', @project ? @project.name : 'All Projects']
      csv << []  # Empty row separator

      csv << ['ID', 'Name', 'Vendor ID', 'Country', 'Email', 'Phone', 'Contact Person', 'Address', 'Website', 'Active', 'Scope', 'Purchase Requests Count', 'Total PR Value', 'Created']

      vendors.each do |vendor|
        total_value = PurchaseRequest.committed_sum(vendor.purchase_requests)
        csv << [
          vendor.id,
          vendor.name,
          vendor.vendor_id,
          vendor.respond_to?(:country) ? vendor.country : '',
          vendor.email,
          vendor.phone,
          vendor.contact_person,
          vendor.address,
          vendor.website,
          vendor.is_active? ? 'Yes' : 'No',
          vendor.project_specific? ? 'Project' : 'Global',
          vendor.purchase_requests.count,
          total_value,
          vendor.created_at&.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_tpc_codes_csv(tpc_codes)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      # Report metadata header
      csv << ['Report', 'TPC Codes Report']
      csv << ['Generated By', "#{User.current.name} (#{User.current.mail})"]
      csv << ['Generated At', Time.current.strftime('%Y-%m-%d %H:%M:%S')]
      csv << ['Project', @project ? @project.name : 'All Projects']
      csv << []  # Empty row separator

      csv << ['TPC Number', 'Owner Name', 'Owner Email', 'Description', 'Active', 'Scope', 'CAPEX Items', 'CAPEX Total Value', 'OPEX Items', 'OPEX Total Value', 'Direct PR Count', 'Direct PR Value', 'Total Budget', 'Created']

      tpc_codes.each do |tpc|
        capex_total = tpc.capex.sum(:total_amount) rescue 0
        opex_total = tpc.opex.sum(:total_amount) rescue 0
        direct_prs = PurchaseRequest.where(tpc_code_id: tpc.id)
        direct_pr_count = direct_prs.count
        direct_pr_value = PurchaseRequest.committed_sum(direct_prs)
        total_budget = capex_total + opex_total

        csv << [
          tpc.tpc_number,
          tpc.tpc_owner_name,
          tpc.tpc_email,
          tpc.description,
          tpc.is_active? ? 'Yes' : 'No',
          tpc.project_id? ? 'Project' : 'Global',
          tpc.capex.count,
          capex_total,
          tpc.opex.count,
          opex_total,
          direct_pr_count,
          direct_pr_value,
          total_budget,
          tpc.created_at&.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_capex_csv(capex_items)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      # Report metadata header
      csv << ['Report', 'CAPEX Report']
      csv << ['Generated By', "#{User.current.name} (#{User.current.mail})"]
      csv << ['Generated At', Time.current.strftime('%Y-%m-%d %H:%M:%S')]
      csv << ['Project', @project ? @project.name : 'All Projects']
      csv << []  # Empty row separator

      csv << ['ID', 'Project', 'Year', 'Description', 'TPC Code', 'Total Amount', 'Currency', 'Q1', 'Q2', 'Q3', 'Q4', 'PR Count', 'Utilized Amount', 'Utilization %', 'Remaining Amount', 'Status', 'Created']

      capex_items.each do |capex|
        # Calculate utilization from purchase requests
        prs = PurchaseRequest.where(capex_id: capex.id)
        pr_count = prs.count
        utilized_amount = PurchaseRequest.committed_sum(prs)
        total = capex.total_amount || 0
        utilization_pct = total > 0 ? ((utilized_amount / total.to_f) * 100).round(1) : 0
        remaining = total - utilized_amount

        # Determine status
        status = if utilization_pct >= 100
                   'Over-utilized'
                 elsif utilization_pct >= 80
                   'Near Limit'
                 elsif utilization_pct > 0
                   'Active'
                 else
                   'Unused'
                 end

        csv << [
          capex.id,
          capex.project&.name,
          capex.year,
          capex.description,
          capex.tpc_code,
          capex.total_amount,
          capex.currency,
          capex.q1_amount,
          capex.q2_amount,
          capex.q3_amount,
          capex.q4_amount,
          pr_count,
          utilized_amount,
          "#{utilization_pct}%",
          remaining,
          status,
          capex.created_at&.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_opex_csv(opex_items)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      # Report metadata header
      csv << ['Report', 'OPEX Report']
      csv << ['Generated By', "#{User.current.name} (#{User.current.mail})"]
      csv << ['Generated At', Time.current.strftime('%Y-%m-%d %H:%M:%S')]
      csv << ['Project', @project ? @project.name : 'All Projects']
      csv << []  # Empty row separator

      csv << ['ID', 'Project', 'Year', 'Description', 'TPC Code', 'Category', 'Total Amount', 'Currency', 'Q1', 'Q2', 'Q3', 'Q4', 'PR Count', 'Utilized Amount', 'Utilization %', 'Remaining Amount', 'Status', 'Created']

      opex_items.each do |opex|
        # Calculate utilization from purchase requests
        prs = PurchaseRequest.where(opex_id: opex.id)
        pr_count = prs.count
        utilized_amount = PurchaseRequest.committed_sum(prs)
        total = opex.total_amount || 0
        utilization_pct = total > 0 ? ((utilized_amount / total.to_f) * 100).round(1) : 0
        remaining = total - utilized_amount

        # Determine status
        status = if utilization_pct >= 100
                   'Over-utilized'
                 elsif utilization_pct >= 80
                   'Near Limit'
                 elsif utilization_pct > 0
                   'Active'
                 else
                   'Unused'
                 end

        csv << [
          opex.id,
          opex.project&.name,
          opex.year,
          opex.description,
          opex.tpc_code&.tpc_number,
          opex.opex_category&.name,
          opex.total_amount,
          opex.currency,
          opex.q1_amount,
          opex.q2_amount,
          opex.q3_amount,
          opex.q4_amount,
          pr_count,
          utilized_amount,
          "#{utilization_pct}%",
          remaining,
          status,
          opex.created_at&.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_overview_csv(pr_data, vendor_data, tpc_data, capex_data, opex_data)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      # Report metadata header
      csv << ['Report', 'Executive Overview Report']
      csv << ['Generated By', "#{User.current.name} (#{User.current.mail})"]
      csv << ['Generated At', Time.current.strftime('%Y-%m-%d %H:%M:%S')]
      csv << ['Project', @project ? @project.name : 'All Projects']
      csv << []  # Empty row separator

      csv << ['Report Section', 'Metric', 'Value']

      # High-level KPIs
      csv << ['KPIs', 'Total Purchase Requests', pr_data[:summary][:total_count]]
      csv << ['KPIs', 'Open Purchase Requests', pr_data[:summary][:open_count]]
      csv << ['KPIs', 'Total PR Value', pr_data[:summary][:total_estimated_value]]
      csv << ['KPIs', 'Avg PR Value', pr_data[:summary][:total_count].to_i > 0 ? (pr_data[:summary][:total_estimated_value].to_f / pr_data[:summary][:total_count]).round(2) : 0]

      csv << ['', '', '']

      # Purchase Requests by Status
      csv << ['PR Status Breakdown', '---', '---']
      if pr_data[:status_breakdown].present?
        pr_data[:status_breakdown].each do |status, count|
          csv << ['PR Status', status, count]
        end
      end

      csv << ['', '', '']

      # Budget Distribution
      csv << ['Budget Distribution', '---', '---']
      capex_pr_count = PurchaseRequest.where.not(capex_id: nil).count rescue 0
      opex_pr_count = PurchaseRequest.where.not(opex_id: nil).count rescue 0
      direct_tpc_count = PurchaseRequest.where(capex_id: nil, opex_id: nil).where.not(tpc_code_id: nil).count rescue 0
      non_budgeted_count = PurchaseRequest.where(capex_id: nil, opex_id: nil, tpc_code_id: nil).count rescue 0
      csv << ['Budget Source', 'CAPEX', capex_pr_count]
      csv << ['Budget Source', 'OPEX', opex_pr_count]
      csv << ['Budget Source', 'Direct TPC', direct_tpc_count]
      csv << ['Budget Source', 'Non-budgeted', non_budgeted_count]

      csv << ['', '', '']

      # Currency Usage
      csv << ['Currency Usage', '---', '---']
      currency_data = PurchaseRequest.group(:currency).count rescue {}
      currency_data.each do |currency, count|
        csv << ['Currency', currency || 'Unspecified', count]
      end

      csv << ['', '', '']

      # Vendors summary
      csv << ['Vendors Summary', '---', '---']
      csv << ['Vendors', 'Total Count', vendor_data[:summary][:total_count]]
      csv << ['Vendors', 'Active Count', vendor_data[:summary][:active_count]]
      global_vendor_count = (Vendor.where(project_id: nil).count rescue 0)
      project_vendor_count = (Vendor.where.not(project_id: nil).count rescue 0)
      csv << ['Vendors', 'Global Vendors', global_vendor_count]
      csv << ['Vendors', 'Project-specific Vendors', project_vendor_count]

      csv << ['', '', '']

      # Vendor Countries
      csv << ['Vendor Geographic Distribution', '---', '---']
      country_data = Vendor.where.not(country: [nil, '']).group(:country).count rescue {}
      country_data.each do |country, count|
        csv << ['Vendor Country', country, count]
      end
      unspecified_count = Vendor.where(country: [nil, '']).count rescue 0
      csv << ['Vendor Country', 'Unspecified', unspecified_count] if unspecified_count > 0

      csv << ['', '', '']

      # TPC Codes summary
      csv << ['TPC Codes Summary', '---', '---']
      csv << ['TPC Codes', 'Total Count', tpc_data[:summary][:total_count]]
      csv << ['TPC Codes', 'Active Count', tpc_data[:summary][:active_count]]

      csv << ['', '', '']

      # CAPEX summary
      csv << ['CAPEX Summary', '---', '---']
      csv << ['CAPEX', 'Total Items', capex_data[:summary][:total_items]]
      csv << ['CAPEX', 'Total Budget Value', capex_data[:summary][:total_value]]
      capex_utilized = PurchaseRequest.committed_sum(PurchaseRequest.where.not(capex_id: nil)) rescue 0
      csv << ['CAPEX', 'Utilized Amount', capex_utilized]
      csv << ['CAPEX', 'Utilization %', capex_data[:summary][:total_value].to_f > 0 ? "#{((capex_utilized / capex_data[:summary][:total_value].to_f) * 100).round(1)}%" : '0%']

      csv << ['', '', '']

      # OPEX summary
      csv << ['OPEX Summary', '---', '---']
      csv << ['OPEX', 'Total Items', opex_data[:summary][:total_items]]
      csv << ['OPEX', 'Total Budget Value', opex_data[:summary][:total_value]]
      opex_utilized = PurchaseRequest.committed_sum(PurchaseRequest.where.not(opex_id: nil)) rescue 0
      csv << ['OPEX', 'Utilized Amount', opex_utilized]
      csv << ['OPEX', 'Utilization %', opex_data[:summary][:total_value].to_f > 0 ? "#{((opex_utilized / opex_data[:summary][:total_value].to_f) * 100).round(1)}%" : '0%']

      csv << ['', '', '']

      # Combined Budget Overview
      csv << ['Combined Budget', '---', '---']
      total_budget = (capex_data[:summary][:total_value] || 0) + (opex_data[:summary][:total_value] || 0)
      total_utilized = capex_utilized + opex_utilized
      csv << ['Combined', 'Total Budget (CAPEX + OPEX)', total_budget]
      csv << ['Combined', 'Total Utilized', total_utilized]
      csv << ['Combined', 'Total Remaining', total_budget - total_utilized]
      csv << ['Combined', 'Overall Utilization %', total_budget > 0 ? "#{((total_utilized / total_budget.to_f) * 100).round(1)}%" : '0%']
    end
  end
  
  
  def send_csv_data(csv_data, filename)
    send_data csv_data,
              filename: "#{filename}_#{@project ? @project.identifier + '_' : ''}#{Date.current.strftime('%Y%m%d')}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end
  
  def generate_pdf_report(title, report_data)
    pdf = BrandedReportPdf.new(
      report_title:  title,
      project:       @project,
      selected_year: @selected_year
    )
    pdf.add_page
    pdf.print_cover(generated_at: report_data[:generated_at], intro: pdf_intro_for(title))

    # KPI summary tiles (top 6 numeric values from report_data[:summary])
    if report_data[:summary].is_a?(Hash) && report_data[:summary].any?
      pdf.section_heading('Summary')
      kpi_pairs = report_data[:summary].to_a.first(6).map do |k, v|
        [k.to_s.tr('_', ' ').split.map(&:capitalize).join(' '), v]
      end
      pdf.kpi_grid(kpi_pairs)
    end
    
    # Additional data sections can be added here based on report type
    case title
    when 'Purchase Requests Report'
      add_purchase_requests_pdf_content(pdf, report_data)
    when 'Vendors Report'
      add_vendors_pdf_content(pdf, report_data)
    when 'TPC Codes Report'
      add_tpc_codes_pdf_content(pdf, report_data)
    when 'CAPEX Report'
      add_capex_pdf_content(pdf, report_data)
    when 'OPEX Report'
      add_opex_pdf_content(pdf, report_data)
    when 'Executive Overview Report'
      add_overview_pdf_content(pdf, report_data)
    end
    
    pdf.output
  end
  
  def add_purchase_requests_pdf_content(pdf, report_data)
    # Status breakdown with chart visualization
    if report_data[:status_breakdown].any?
      # Add chart using helper
      PdfChartHelper.generate_bar_chart(pdf, report_data[:status_breakdown], {
        title: 'Status Distribution',
        width: 400,
        height: 180,
        type: :bar
      })
      
      # Add summary table below chart
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'Status Summary', 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(100, 6, 'Status', 1, 0, 'C')
      pdf.cell(40, 6, 'Count', 1, 0, 'C')
      pdf.cell(40, 6, 'Percentage', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      total_requests = report_data[:status_breakdown].values.sum
      
      report_data[:status_breakdown].each do |status, count|
        percentage = total_requests > 0 ? ((count.to_f / total_requests) * 100).round(1) : 0
        
        pdf.cell(100, 5, status, 1, 0, 'L')
        pdf.cell(40, 5, count.to_s, 1, 0, 'C')
        pdf.cell(40, 5, "#{percentage}%", 1, 1, 'C')
      end
      pdf.ln(5)
    end
    
    # Priority Analysis with pie chart
    if report_data[:priority_breakdown].any?
      PdfChartHelper.generate_pie_chart(pdf, report_data[:priority_breakdown], {
        title: 'Priority Distribution',
        width: 300,
        height: 300
      })
    end
    
    # Monthly Trend Analysis with line chart
    if report_data[:monthly_trend].any?
      # Convert monthly trend to chart-friendly format
      monthly_data = report_data[:monthly_trend].to_a.last(6).to_h
      trend_labels = monthly_data.keys.map { |date| date.strftime('%b %Y') }
      
      PdfChartHelper.generate_line_chart(pdf, monthly_data, {
        title: 'Monthly Creation Trend (Last 6 Months)',
        width: 450,
        height: 200,
        type: :line
      })
    end
    
    # Top Vendors Analysis
    if report_data[:vendor_stats].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'Top Vendors by Request Count', 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 8)
      pdf.cell(15, 6, 'Rank', 1, 0, 'C')
      pdf.cell(80, 6, 'Vendor Name', 1, 0, 'C')
      pdf.cell(25, 6, 'Requests', 1, 0, 'C')
      pdf.cell(60, 6, 'Activity Level', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      max_vendor_count = report_data[:vendor_stats].first[1] if report_data[:vendor_stats].any?
      
      report_data[:vendor_stats].first(5).each_with_index do |(vendor_info, count), index|
        vendor_name = vendor_info.is_a?(Array) ? vendor_info[0] : vendor_info.to_s
        activity_bars = max_vendor_count > 0 ? '#' * ((count.to_f / max_vendor_count) * 15).to_i : ''
        
        pdf.cell(15, 5, "##{index + 1}", 1, 0, 'C')
        pdf.cell(80, 5, vendor_name.length > 35 ? "#{vendor_name[0, 32]}..." : vendor_name, 1, 0, 'L')
        pdf.cell(25, 5, count.to_s, 1, 0, 'C')
        pdf.cell(60, 5, activity_bars, 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # Recent requests table
    if report_data[:recent_requests].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'Recent Purchase Requests', 0, 1, 'L')
      
      # Table header
      pdf.set_font('helvetica', 'B', 8)
      pdf.cell(15, 6, 'ID', 1, 0, 'C')
      pdf.cell(60, 6, 'Title', 1, 0, 'C')
      pdf.cell(40, 6, 'Project', 1, 0, 'C')
      pdf.cell(25, 6, 'Status', 1, 0, 'C')
      pdf.cell(25, 6, 'Priority', 1, 0, 'C')
      pdf.cell(25, 6, 'Est. Price', 1, 1, 'C')
      
      # Table rows
      pdf.set_font('helvetica', '', 7)
      report_data[:recent_requests].first(10).each do |request|
        pdf.cell(15, 5, request.id.to_s, 1, 0, 'C')
        pdf.cell(60, 5, request.title.to_s.length > 30 ? "#{request.title.to_s[0, 27]}..." : request.title.to_s, 1, 0, 'L')
        pdf.cell(40, 5, request.project&.name || '-', 1, 0, 'L')
        pdf.cell(25, 5, request.status&.name || '-', 1, 0, 'C')
        pdf.cell(25, 5, request.priority&.capitalize || '-', 1, 0, 'C')
        price = request.estimated_price ? "#{request.currency} #{number_with_delimiter(request.estimated_price)}" : '-'
        pdf.cell(25, 5, price, 1, 1, 'R')
      end
    end
  end
  
  def add_vendors_pdf_content(pdf, report_data)
    # Vendor activity with visualization
    if report_data[:vendor_activity].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'Top Active Vendors', 0, 1, 'L')
      
      # Create vendor activity table
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(15, 6, 'Rank', 1, 0, 'C')
      pdf.cell(70, 6, 'Vendor Name', 1, 0, 'C')
      pdf.cell(25, 6, 'Requests', 1, 0, 'C')
      pdf.cell(70, 6, 'Activity Level', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      max_vendor_activity = report_data[:vendor_activity].first[1] if report_data[:vendor_activity].any?
      
      report_data[:vendor_activity].first(10).each_with_index do |(vendor_info, count), index|
        vendor_name = vendor_info.is_a?(Array) ? vendor_info[1] : vendor_info.to_s
        bars = max_vendor_activity > 0 ? '#' * ((count.to_f / max_vendor_activity) * 15).to_i : ''
        
        pdf.cell(15, 5, "##{index + 1}", 1, 0, 'C')
        pdf.cell(70, 5, vendor_name.length > 30 ? "#{vendor_name[0, 27]}..." : vendor_name, 1, 0, 'L')
        pdf.cell(25, 5, count.to_s, 1, 0, 'C')
        pdf.cell(70, 5, "#{bars} (#{count})", 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # Vendor engagement analysis
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 8, 'Vendor Engagement Analysis', 0, 1, 'L')
    
    pdf.set_font('helvetica', 'B', 9)
    pdf.cell(50, 6, 'Metric', 1, 0, 'C')
    pdf.cell(30, 6, 'Count', 1, 0, 'C')
    pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
    pdf.cell(70, 6, 'Visual Representation', 1, 1, 'C')
    
    pdf.set_font('helvetica', '', 8)
    total_vendors = report_data[:summary][:total_count]
    active_vendors = report_data[:summary][:active_count]
    engaged_vendors = report_data[:summary][:vendors_with_requests]
    
    # Active vendors
    if total_vendors > 0
      active_percentage = ((active_vendors.to_f / total_vendors) * 100).round(1)
      active_bars = '#' * (active_percentage / 5).to_i + '.' * ((100 - active_percentage) / 5).to_i
      
      pdf.cell(50, 5, 'Active Vendors', 1, 0, 'L')
      pdf.cell(30, 5, "#{active_vendors}/#{total_vendors}", 1, 0, 'C')
      pdf.cell(30, 5, "#{active_percentage}%", 1, 0, 'C')
      pdf.cell(70, 5, active_bars[0, 15], 1, 1, 'L')
      
      # Engaged vendors
      engaged_percentage = ((engaged_vendors.to_f / total_vendors) * 100).round(1)
      engaged_bars = '#' * (engaged_percentage / 5).to_i + '.' * ((100 - engaged_percentage) / 5).to_i
      
      pdf.cell(50, 5, 'Vendors with Requests', 1, 0, 'L')
      pdf.cell(30, 5, "#{engaged_vendors}/#{total_vendors}", 1, 0, 'C')
      pdf.cell(30, 5, "#{engaged_percentage}%", 1, 0, 'C')
      pdf.cell(70, 5, engaged_bars[0, 15], 1, 1, 'L')
    end
    
    # Project distribution if available
    if report_data[:project_distribution]
      pdf.ln(5)
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'Project Distribution', 0, 1, 'L')

      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(15, 6, 'Rank', 1, 0, 'C')
      pdf.cell(70, 6, 'Project Name', 1, 0, 'C')
      pdf.cell(25, 6, 'Vendors', 1, 0, 'C')
      pdf.cell(70, 6, 'Distribution', 1, 1, 'C')

      pdf.set_font('helvetica', '', 8)
      max_project_vendors = report_data[:project_distribution].values.max

      report_data[:project_distribution].first(8).each_with_index do |(project, count), index|
        bars = max_project_vendors > 0 ? '#' * ((count.to_f / max_project_vendors) * 15).to_i : ''

        pdf.cell(15, 5, "##{index + 1}", 1, 0, 'C')
        pdf.cell(70, 5, project.length > 30 ? "#{project[0, 27]}..." : project, 1, 0, 'L')
        pdf.cell(25, 5, count.to_s, 1, 0, 'C')
        pdf.cell(70, 5, bars, 1, 1, 'L')
      end
    end

    # Geographic Distribution
    pdf.ln(5)
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 8, 'Geographic Distribution', 0, 1, 'L')

    country_data = Vendor.where.not(country: [nil, '']).group(:country).count rescue {}
    unspecified_vendors = Vendor.where(country: [nil, '']).count rescue 0

    if country_data.any? || unspecified_vendors > 0
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(15, 6, 'Rank', 1, 0, 'C')
      pdf.cell(60, 6, 'Country', 1, 0, 'C')
      pdf.cell(25, 6, 'Vendors', 1, 0, 'C')
      pdf.cell(30, 6, '% of Total', 1, 0, 'C')
      pdf.cell(50, 6, 'Distribution', 1, 1, 'C')

      pdf.set_font('helvetica', '', 8)
      total_vendors = country_data.values.sum + unspecified_vendors
      sorted_countries = country_data.sort_by { |_, count| -count }.first(8)
      max_country_vendors = sorted_countries.first ? sorted_countries.first[1] : 1

      sorted_countries.each_with_index do |(country, count), index|
        pct = total_vendors > 0 ? ((count / total_vendors.to_f) * 100).round(1) : 0
        bars = max_country_vendors > 0 ? '#' * ((count.to_f / max_country_vendors) * 10).to_i : ''

        pdf.cell(15, 5, "##{index + 1}", 1, 0, 'C')
        pdf.cell(60, 5, country.length > 25 ? "#{country[0, 22]}..." : country, 1, 0, 'L')
        pdf.cell(25, 5, count.to_s, 1, 0, 'C')
        pdf.cell(30, 5, "#{pct}%", 1, 0, 'C')
        pdf.cell(50, 5, bars, 1, 1, 'L')
      end

      if unspecified_vendors > 0
        pct = total_vendors > 0 ? ((unspecified_vendors / total_vendors.to_f) * 100).round(1) : 0
        pdf.cell(15, 5, "-", 1, 0, 'C')
        pdf.cell(60, 5, 'Unspecified', 1, 0, 'L')
        pdf.cell(25, 5, unspecified_vendors.to_s, 1, 0, 'C')
        pdf.cell(30, 5, "#{pct}%", 1, 0, 'C')
        pdf.cell(50, 5, '', 1, 1, 'L')
      end
    else
      pdf.set_font('helvetica', 'I', 9)
      pdf.cell(0, 5, 'No country data available. Please update vendor records with country information.', 0, 1, 'L')
    end
  end
  
  def add_tpc_codes_pdf_content(pdf, report_data)
    # TPC usage summary with visualization
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 8, 'TPC Code Usage Analysis', 0, 1, 'L')
    
    # Usage summary table
    pdf.set_font('helvetica', 'B', 9)
    pdf.cell(50, 6, 'Usage Type', 1, 0, 'C')
    pdf.cell(30, 6, 'Codes Used', 1, 0, 'C')
    pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
    pdf.cell(70, 6, 'Visual Representation', 1, 1, 'C')
    
    pdf.set_font('helvetica', '', 8)
    total_codes = report_data[:summary][:total_count]
    capex_codes = report_data[:summary][:with_capex]
    opex_codes = report_data[:summary][:with_opex]
    
    if total_codes > 0
      # CAPEX usage
      capex_percentage = ((capex_codes.to_f / total_codes) * 100).round(1)
      capex_bars = '#' * (capex_percentage / 5).to_i + '.' * ((100 - capex_percentage) / 5).to_i
      
      pdf.cell(50, 5, 'CAPEX Allocations', 1, 0, 'L')
      pdf.cell(30, 5, "#{capex_codes}/#{total_codes}", 1, 0, 'C')
      pdf.cell(30, 5, "#{capex_percentage}%", 1, 0, 'C')
      pdf.cell(70, 5, capex_bars[0, 15], 1, 1, 'L')
      
      # OPEX usage
      opex_percentage = ((opex_codes.to_f / total_codes) * 100).round(1)
      opex_bars = '#' * (opex_percentage / 5).to_i + '.' * ((100 - opex_percentage) / 5).to_i
      
      pdf.cell(50, 5, 'OPEX Allocations', 1, 0, 'L')
      pdf.cell(30, 5, "#{opex_codes}/#{total_codes}", 1, 0, 'C')
      pdf.cell(30, 5, "#{opex_percentage}%", 1, 0, 'C')
      pdf.cell(70, 5, opex_bars[0, 15], 1, 1, 'L')
      
      # Active codes
      active_codes = report_data[:summary][:active_count]
      active_percentage = ((active_codes.to_f / total_codes) * 100).round(1)
      active_bars = '#' * (active_percentage / 5).to_i + '.' * ((100 - active_percentage) / 5).to_i
      
      pdf.cell(50, 5, 'Active TPC Codes', 1, 0, 'L')
      pdf.cell(30, 5, "#{active_codes}/#{total_codes}", 1, 0, 'C')
      pdf.cell(30, 5, "#{active_percentage}%", 1, 0, 'C')
      pdf.cell(70, 5, active_bars[0, 15], 1, 1, 'L')
    end
    pdf.ln(5)
    
    # CAPEX allocation analysis
    if report_data[:capex_totals].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'CAPEX Allocations by TPC Code', 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 8)
      pdf.cell(15, 6, 'Rank', 1, 0, 'C')
      pdf.cell(50, 6, 'TPC Code', 1, 0, 'C')
      pdf.cell(40, 6, 'CAPEX Amount', 1, 0, 'C')
      pdf.cell(75, 6, 'Allocation Level', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      sorted_capex = report_data[:capex_totals].sort_by { |_, amount| -amount }
      max_capex = sorted_capex.first[1] if sorted_capex.any?
      
      sorted_capex.first(8).each_with_index do |(tpc_code, amount), index|
        bars = max_capex > 0 ? '#' * ((amount / max_capex) * 15).to_i : ''
        
        pdf.cell(15, 5, "##{index + 1}", 1, 0, 'C')
        pdf.cell(50, 5, tpc_code.to_s, 1, 0, 'L')
        pdf.cell(40, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(75, 5, bars, 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # OPEX allocation analysis
    if report_data[:opex_totals].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'OPEX Allocations by TPC Code', 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 8)
      pdf.cell(15, 6, 'Rank', 1, 0, 'C')
      pdf.cell(50, 6, 'TPC Code', 1, 0, 'C')
      pdf.cell(40, 6, 'OPEX Amount', 1, 0, 'C')
      pdf.cell(75, 6, 'Allocation Level', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      sorted_opex = report_data[:opex_totals].sort_by { |_, amount| -amount }
      max_opex = sorted_opex.first[1] if sorted_opex.any?
      
      sorted_opex.first(8).each_with_index do |(tpc_code, amount), index|
        bars = max_opex > 0 ? '#' * ((amount / max_opex) * 15).to_i : ''
        
        pdf.cell(15, 5, "##{index + 1}", 1, 0, 'C')
        pdf.cell(50, 5, tpc_code.to_s, 1, 0, 'L')
        pdf.cell(40, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(75, 5, bars, 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # Combined usage analysis
    if report_data[:capex_usage].any? || report_data[:opex_usage].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'TPC Code Usage Frequency', 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 8)
      pdf.cell(50, 6, 'TPC Code', 1, 0, 'C')
      pdf.cell(25, 6, 'CAPEX Uses', 1, 0, 'C')
      pdf.cell(25, 6, 'OPEX Uses', 1, 0, 'C')
      pdf.cell(25, 6, 'Total Uses', 1, 0, 'C')
      pdf.cell(55, 6, 'Usage Pattern', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      
      # Combine CAPEX and OPEX usage data
      all_tpc_codes = (report_data[:capex_usage].keys + report_data[:opex_usage].keys).uniq
      max_total_usage = 0
      
      usage_data = all_tpc_codes.map do |tpc_code|
        capex_count = report_data[:capex_usage][tpc_code] || 0
        opex_count = report_data[:opex_usage][tpc_code] || 0
        total_count = capex_count + opex_count
        max_total_usage = [max_total_usage, total_count].max
        [tpc_code, capex_count, opex_count, total_count]
      end.sort_by { |_, _, _, total| -total }
      
      usage_data.first(10).each do |tpc_code, capex_count, opex_count, total_count|
        bars = max_total_usage > 0 ? '#' * ((total_count.to_f / max_total_usage) * 12).to_i : ''
        
        pdf.cell(50, 5, tpc_code.to_s, 1, 0, 'L')
        pdf.cell(25, 5, capex_count.to_s, 1, 0, 'C')
        pdf.cell(25, 5, opex_count.to_s, 1, 0, 'C')
        pdf.cell(25, 5, total_count.to_s, 1, 0, 'C')
        pdf.cell(55, 5, "#{bars} (#{total_count})", 1, 1, 'L')
      end
    end
  end
  
  def add_capex_pdf_content(pdf, report_data)
    # Yearly totals with visualization
    if report_data[:yearly_totals].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'CAPEX by Year', 0, 1, 'L')
      
      # Create yearly table with visual bars
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(30, 6, 'Year', 1, 0, 'C')
      pdf.cell(45, 6, 'Amount', 1, 0, 'C')
      pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
      pdf.cell(75, 6, 'Visual Distribution', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      total_capex = report_data[:yearly_totals].values.sum
      max_amount = report_data[:yearly_totals].values.max
      
      report_data[:yearly_totals].each do |year, amount|
        percentage = total_capex > 0 ? ((amount / total_capex) * 100).round(1) : 0
        bars = max_amount > 0 ? '#' * ((amount / max_amount) * 15).to_i : ''
        
        pdf.cell(30, 5, year.to_s, 1, 0, 'C')
        pdf.cell(45, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(30, 5, "#{percentage}%", 1, 0, 'C')
        pdf.cell(75, 5, bars, 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # Quarterly breakdown for current year
    if report_data[:quarterly_breakdown]
      current_year = Date.current.year
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, "#{current_year} Quarterly Breakdown", 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(30, 6, 'Quarter', 1, 0, 'C')
      pdf.cell(40, 6, 'Amount', 1, 0, 'C')
      pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
      pdf.cell(80, 6, 'Visual Distribution', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      quarterly_total = report_data[:quarterly_breakdown].values.sum
      max_quarterly = report_data[:quarterly_breakdown].values.max
      
      [:q1, :q2, :q3, :q4].each_with_index do |quarter, index|
        amount = report_data[:quarterly_breakdown][quarter]
        percentage = quarterly_total > 0 ? ((amount / quarterly_total) * 100).round(1) : 0
        bars = max_quarterly > 0 ? '#' * ((amount / max_quarterly) * 15).to_i : ''
        
        pdf.cell(30, 5, "Q#{index + 1} #{current_year}", 1, 0, 'C')
        pdf.cell(40, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(30, 5, "#{percentage}%", 1, 0, 'C')
        pdf.cell(80, 5, bars, 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # TPC Code distribution
    if report_data[:tpc_distribution].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'Top TPC Code Allocations', 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 8)
      pdf.cell(15, 6, 'Rank', 1, 0, 'C')
      pdf.cell(50, 6, 'TPC Code', 1, 0, 'C')
      pdf.cell(40, 6, 'Amount', 1, 0, 'C')
      pdf.cell(75, 6, 'Allocation Level', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      max_tpc_amount = report_data[:tpc_distribution].first[1] if report_data[:tpc_distribution].any?
      
      report_data[:tpc_distribution].first(8).each_with_index do |(tpc_code, amount), index|
        bars = max_tpc_amount > 0 ? '#' * ((amount / max_tpc_amount) * 15).to_i : ''
        
        pdf.cell(15, 5, "##{index + 1}", 1, 0, 'C')
        pdf.cell(50, 5, tpc_code.to_s, 1, 0, 'L')
        pdf.cell(40, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(75, 5, bars, 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # Currency breakdown
    if report_data[:currency_breakdown].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'Currency Distribution', 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(30, 6, 'Currency', 1, 0, 'C')
      pdf.cell(40, 6, 'Amount', 1, 0, 'C')
      pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
      pdf.cell(80, 6, 'Distribution', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      currency_total = report_data[:currency_breakdown].values.sum
      
      report_data[:currency_breakdown].each do |currency, amount|
        percentage = currency_total > 0 ? ((amount / currency_total) * 100).round(1) : 0
        bars = '#' * (percentage / 5).to_i + '.' * ((100 - percentage) / 5).to_i
        
        pdf.cell(30, 5, currency, 1, 0, 'C')
        pdf.cell(40, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(30, 5, "#{percentage}%", 1, 0, 'C')
        pdf.cell(80, 5, bars[0, 20], 1, 1, 'L')
      end
    end
  end
  
  def add_opex_pdf_content(pdf, report_data)
    # Category breakdown with visualization
    if report_data[:category_breakdown].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'OPEX by Category', 0, 1, 'L')
      
      # Create category table with visual bars
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(15, 6, 'Rank', 1, 0, 'C')
      pdf.cell(50, 6, 'Category', 1, 0, 'C')
      pdf.cell(40, 6, 'Amount', 1, 0, 'C')
      pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
      pdf.cell(45, 6, 'Visual', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      total_opex = report_data[:category_breakdown].values.sum
      max_category_amount = report_data[:category_breakdown].values.max
      
      report_data[:category_breakdown].each_with_index do |(category, amount), index|
        percentage = total_opex > 0 ? ((amount / total_opex) * 100).round(1) : 0
        bars = max_category_amount > 0 ? '#' * ((amount / max_category_amount) * 12).to_i : ''
        
        pdf.cell(15, 5, "##{index + 1}", 1, 0, 'C')
        pdf.cell(50, 5, category.length > 20 ? "#{category[0, 17]}..." : category, 1, 0, 'L')
        pdf.cell(40, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(30, 5, "#{percentage}%", 1, 0, 'C')
        pdf.cell(45, 5, bars, 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # Yearly totals with visualization
    if report_data[:yearly_totals].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'OPEX by Year', 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(30, 6, 'Year', 1, 0, 'C')
      pdf.cell(45, 6, 'Amount', 1, 0, 'C')
      pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
      pdf.cell(75, 6, 'Visual Distribution', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      yearly_total = report_data[:yearly_totals].values.sum
      max_yearly = report_data[:yearly_totals].values.max
      
      report_data[:yearly_totals].each do |year, amount|
        percentage = yearly_total > 0 ? ((amount / yearly_total) * 100).round(1) : 0
        bars = max_yearly > 0 ? '#' * ((amount / max_yearly) * 15).to_i : ''
        
        pdf.cell(30, 5, year.to_s, 1, 0, 'C')
        pdf.cell(45, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(30, 5, "#{percentage}%", 1, 0, 'C')
        pdf.cell(75, 5, bars, 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # Quarterly breakdown for current year
    if report_data[:quarterly_breakdown]
      current_year = Date.current.year
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, "#{current_year} Quarterly Breakdown", 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(30, 6, 'Quarter', 1, 0, 'C')
      pdf.cell(40, 6, 'Amount', 1, 0, 'C')
      pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
      pdf.cell(80, 6, 'Visual Distribution', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      quarterly_total = report_data[:quarterly_breakdown].values.sum
      max_quarterly = report_data[:quarterly_breakdown].values.max
      
      [:q1, :q2, :q3, :q4].each_with_index do |quarter, index|
        amount = report_data[:quarterly_breakdown][quarter]
        percentage = quarterly_total > 0 ? ((amount / quarterly_total) * 100).round(1) : 0
        bars = max_quarterly > 0 ? '#' * ((amount / max_quarterly) * 15).to_i : ''
        
        pdf.cell(30, 5, "Q#{index + 1} #{current_year}", 1, 0, 'C')
        pdf.cell(40, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(30, 5, "#{percentage}%", 1, 0, 'C')
        pdf.cell(80, 5, bars, 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # TPC Code distribution
    if report_data[:tpc_distribution].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'Top TPC Code Allocations', 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 8)
      pdf.cell(15, 6, 'Rank', 1, 0, 'C')
      pdf.cell(50, 6, 'TPC Code', 1, 0, 'C')
      pdf.cell(40, 6, 'Amount', 1, 0, 'C')
      pdf.cell(75, 6, 'Allocation Level', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      max_tpc_amount = report_data[:tpc_distribution].first[1] if report_data[:tpc_distribution].any?
      
      report_data[:tpc_distribution].first(8).each_with_index do |(tpc_code, amount), index|
        bars = max_tpc_amount > 0 ? '#' * ((amount / max_tpc_amount) * 15).to_i : ''
        
        pdf.cell(15, 5, "##{index + 1}", 1, 0, 'C')
        pdf.cell(50, 5, tpc_code.to_s, 1, 0, 'L')
        pdf.cell(40, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(75, 5, bars, 1, 1, 'L')
      end
      pdf.ln(5)
    end
    
    # Currency breakdown
    if report_data[:currency_breakdown].any?
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'Currency Distribution', 0, 1, 'L')
      
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(30, 6, 'Currency', 1, 0, 'C')
      pdf.cell(40, 6, 'Amount', 1, 0, 'C')
      pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
      pdf.cell(80, 6, 'Distribution', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      currency_total = report_data[:currency_breakdown].values.sum
      
      report_data[:currency_breakdown].each do |currency, amount|
        percentage = currency_total > 0 ? ((amount / currency_total) * 100).round(1) : 0
        bars = '#' * (percentage / 5).to_i + '.' * ((100 - percentage) / 5).to_i
        
        pdf.cell(30, 5, currency, 1, 0, 'C')
        pdf.cell(40, 5, "$#{number_with_delimiter(amount.round(2))}", 1, 0, 'R')
        pdf.cell(30, 5, "#{percentage}%", 1, 0, 'C')
        pdf.cell(80, 5, bars[0, 20], 1, 1, 'L')
      end
    end
  end
  
  def add_overview_pdf_content(pdf, report_data)
    # Executive summary
    if report_data[:executive_summary]
      pdf.set_font('helvetica', 'B', 12)
      pdf.cell(0, 8, 'Executive Summary', 0, 1, 'L')
      pdf.set_font('helvetica', '', 9)

      summary = report_data[:executive_summary]
      pdf.cell(0, 5, "Purchase Requests: #{summary[:purchase_requests][:total]} total, #{summary[:purchase_requests][:open]} open", 0, 1, 'L')
      pdf.cell(0, 5, "Vendors: #{summary[:vendors][:total]} total, #{summary[:vendors][:active]} active", 0, 1, 'L')
      pdf.cell(0, 5, "TPC Codes: #{summary[:tpc_codes][:total]} total, #{summary[:tpc_codes][:active]} active", 0, 1, 'L')
      pdf.cell(0, 5, "Total Budget: $#{format_number(report_data[:total_budget].round(2))}", 0, 1, 'L')
      pdf.ln(5)
    end

    # Budget Distribution Chart (CAPEX vs OPEX)
    capex_value = report_data[:executive_summary][:capex][:total_value]
    opex_value = report_data[:executive_summary][:opex][:total_value]

    if capex_value > 0 || opex_value > 0
      budget_data = {
        'CAPEX' => capex_value,
        'OPEX' => opex_value
      }

      PdfChartHelper.generate_pie_chart(pdf, budget_data, {
        title: 'Budget Distribution (CAPEX vs OPEX)',
        width: 350,
        height: 350
      })
    end

    # Budget Distribution by Source (PR allocation)
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 8, 'Purchase Request Budget Sources', 0, 1, 'L')

    pdf.set_font('helvetica', 'B', 8)
    pdf.cell(50, 6, 'Budget Source', 1, 0, 'C')
    pdf.cell(30, 6, 'PR Count', 1, 0, 'C')
    pdf.cell(40, 6, 'Total Value', 1, 0, 'C')
    pdf.cell(30, 6, '% of Total', 1, 1, 'C')

    pdf.set_font('helvetica', '', 8)
    capex_pr_count = PurchaseRequest.where.not(capex_id: nil).count rescue 0
    capex_pr_value = PurchaseRequest.committed_sum(PurchaseRequest.where.not(capex_id: nil)) rescue 0
    opex_pr_count = PurchaseRequest.where.not(opex_id: nil).count rescue 0
    opex_pr_value = PurchaseRequest.committed_sum(PurchaseRequest.where.not(opex_id: nil)) rescue 0
    direct_tpc_count = PurchaseRequest.where(capex_id: nil, opex_id: nil).where.not(tpc_code_id: nil).count rescue 0
    direct_tpc_value = PurchaseRequest.committed_sum(PurchaseRequest.where(capex_id: nil, opex_id: nil).where.not(tpc_code_id: nil)) rescue 0
    non_budgeted_count = PurchaseRequest.where(capex_id: nil, opex_id: nil, tpc_code_id: nil).count rescue 0
    non_budgeted_value = PurchaseRequest.committed_sum(PurchaseRequest.where(capex_id: nil, opex_id: nil, tpc_code_id: nil)) rescue 0
    total_pr_value = capex_pr_value + opex_pr_value + direct_tpc_value + non_budgeted_value

    [
      ['CAPEX', capex_pr_count, capex_pr_value],
      ['OPEX', opex_pr_count, opex_pr_value],
      ['Direct TPC', direct_tpc_count, direct_tpc_value],
      ['Non-budgeted', non_budgeted_count, non_budgeted_value]
    ].each do |source, count, value|
      pct = total_pr_value > 0 ? ((value / total_pr_value.to_f) * 100).round(1) : 0
      pdf.cell(50, 5, source, 1, 0, 'L')
      pdf.cell(30, 5, count.to_s, 1, 0, 'C')
      pdf.cell(40, 5, "$#{format_number(value.round(0))}", 1, 0, 'R')
      pdf.cell(30, 5, "#{pct}%", 1, 1, 'C')
    end
    pdf.ln(5)

    # Currency Usage Analysis
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 8, 'Currency Usage Analysis', 0, 1, 'L')

    currency_data = PurchaseRequest.group(:currency).count rescue {}
    currency_values = PurchaseRequest.budgeted.group(:currency).where.not(estimated_price: nil).sum(:estimated_price) rescue {}

    if currency_data.any?
      pdf.set_font('helvetica', 'B', 8)
      pdf.cell(40, 6, 'Currency', 1, 0, 'C')
      pdf.cell(30, 6, 'PR Count', 1, 0, 'C')
      pdf.cell(40, 6, 'Total Value', 1, 0, 'C')
      pdf.cell(40, 6, '% of PRs', 1, 1, 'C')

      pdf.set_font('helvetica', '', 8)
      total_prs = currency_data.values.sum
      currency_data.each do |currency, count|
        curr_name = currency.present? ? currency : 'Unspecified'
        curr_value = currency_values[currency] || 0
        pct = total_prs > 0 ? ((count / total_prs.to_f) * 100).round(1) : 0
        pdf.cell(40, 5, curr_name, 1, 0, 'L')
        pdf.cell(30, 5, count.to_s, 1, 0, 'C')
        pdf.cell(40, 5, "#{curr_name == 'Unspecified' ? '' : curr_name} #{format_number(curr_value.round(0))}", 1, 0, 'R')
        pdf.cell(40, 5, "#{pct}%", 1, 1, 'C')
      end
    end
    pdf.ln(5)

    # Vendor Geographic Distribution
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 8, 'Vendor Geographic Distribution', 0, 1, 'L')

    country_data = Vendor.where.not(country: [nil, '']).group(:country).count rescue {}
    unspecified_vendors = Vendor.where(country: [nil, '']).count rescue 0

    if country_data.any? || unspecified_vendors > 0
      pdf.set_font('helvetica', 'B', 8)
      pdf.cell(60, 6, 'Country', 1, 0, 'C')
      pdf.cell(30, 6, 'Vendor Count', 1, 0, 'C')
      pdf.cell(40, 6, '% of Vendors', 1, 1, 'C')

      pdf.set_font('helvetica', '', 8)
      total_vendors = country_data.values.sum + unspecified_vendors

      # Show top 10 countries
      sorted_countries = country_data.sort_by { |_, count| -count }.first(10)
      sorted_countries.each do |country, count|
        pct = total_vendors > 0 ? ((count / total_vendors.to_f) * 100).round(1) : 0
        pdf.cell(60, 5, country.length > 25 ? "#{country[0, 22]}..." : country, 1, 0, 'L')
        pdf.cell(30, 5, count.to_s, 1, 0, 'C')
        pdf.cell(40, 5, "#{pct}%", 1, 1, 'C')
      end

      if unspecified_vendors > 0
        pct = total_vendors > 0 ? ((unspecified_vendors / total_vendors.to_f) * 100).round(1) : 0
        pdf.cell(60, 5, 'Unspecified', 1, 0, 'L')
        pdf.cell(30, 5, unspecified_vendors.to_s, 1, 0, 'C')
        pdf.cell(40, 5, "#{pct}%", 1, 1, 'C')
      end
    end
    pdf.ln(5)

    # KPI Dashboard
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 8, 'Key Performance Indicators', 0, 1, 'L')

    # Create KPI table
    pdf.set_font('helvetica', 'B', 8)
    pdf.cell(45, 6, 'Category', 1, 0, 'C')
    pdf.cell(30, 6, 'Total', 1, 0, 'C')
    pdf.cell(30, 6, 'Active/Open', 1, 0, 'C')
    pdf.cell(40, 6, 'Engagement', 1, 0, 'C')
    pdf.cell(45, 6, 'Value/Notes', 1, 1, 'C')

    pdf.set_font('helvetica', '', 8)

    # Purchase Requests KPI
    pr_total = summary[:purchase_requests][:total]
    pr_open = summary[:purchase_requests][:open]
    pr_completion_rate = pr_total > 0 ? (((pr_total - pr_open).to_f / pr_total) * 100).round(1) : 0
    pdf.cell(45, 5, 'Purchase Requests', 1, 0, 'L')
    pdf.cell(30, 5, pr_total.to_s, 1, 0, 'C')
    pdf.cell(30, 5, pr_open.to_s, 1, 0, 'C')
    pdf.cell(40, 5, "#{pr_completion_rate}% Complete", 1, 0, 'C')
    pdf.cell(45, 5, "$#{format_number(summary[:purchase_requests][:total_value].round(0))}", 1, 1, 'R')

    # Vendors KPI
    vendor_total = summary[:vendors][:total]
    vendor_active = summary[:vendors][:active]
    vendor_engaged = summary[:vendors][:with_requests]
    vendor_engagement_rate = vendor_total > 0 ? ((vendor_engaged.to_f / vendor_total) * 100).round(1) : 0
    pdf.cell(45, 5, 'Vendor Management', 1, 0, 'L')
    pdf.cell(30, 5, vendor_total.to_s, 1, 0, 'C')
    pdf.cell(30, 5, vendor_active.to_s, 1, 0, 'C')
    pdf.cell(40, 5, "#{vendor_engagement_rate}% Engaged", 1, 0, 'C')
    pdf.cell(45, 5, "#{vendor_engaged} with requests", 1, 1, 'L')

    # TPC Codes KPI
    tpc_total = summary[:tpc_codes][:total]
    tpc_active = summary[:tpc_codes][:active]
    tpc_utilization = tpc_total > 0 ? ((tpc_active.to_f / tpc_total) * 100).round(1) : 0
    total_allocations = summary[:capex][:total_items] + summary[:opex][:total_items]
    pdf.cell(45, 5, 'TPC Governance', 1, 0, 'L')
    pdf.cell(30, 5, tpc_total.to_s, 1, 0, 'C')
    pdf.cell(30, 5, tpc_active.to_s, 1, 0, 'C')
    pdf.cell(40, 5, "#{tpc_utilization}% Utilized", 1, 0, 'C')
    pdf.cell(45, 5, "#{total_allocations} allocations", 1, 1, 'L')

    pdf.ln(5)

    # Budget Efficiency Analysis
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 8, 'Budget Efficiency Analysis', 0, 1, 'L')
    pdf.set_font('helvetica', '', 9)

    capex_opex_ratio = opex_value > 0 ? (capex_value / opex_value).round(2) : "N/A"
    pdf.cell(0, 5, "CAPEX to OPEX Ratio: #{capex_opex_ratio}:1", 0, 1, 'L')
    pdf.cell(0, 5, "Average Request Value: $#{format_number(report_data[:purchase_requests][:summary][:avg_estimated_value].round(2))}", 0, 1, 'L')
    pdf.cell(0, 5, "Budget Items per TPC Code: #{tpc_total > 0 ? (total_allocations.to_f / tpc_total).round(1) : 0}", 0, 1, 'L')

    # Budget Utilization
    total_budget = capex_value + opex_value
    total_utilized = capex_pr_value + opex_pr_value
    overall_utilization = total_budget > 0 ? ((total_utilized / total_budget.to_f) * 100).round(1) : 0
    pdf.cell(0, 5, "Overall Budget Utilization: #{overall_utilization}% ($#{format_number(total_utilized.round(0))} of $#{format_number(total_budget.round(0))})", 0, 1, 'L')
  end

  def format_number(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end