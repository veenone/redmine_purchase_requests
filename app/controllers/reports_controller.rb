class ReportsController < ApplicationController
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::NumberHelper
  
  before_action :find_optional_project
  before_action :authorize_reports
  
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
      format.csv { send_csv_data(@report_data[:csv_data], 'executive_overview_report') }
      format.json { render json: @report_data }
    end
  end
  
  private
  
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
  
  def generate_purchase_requests_report
    # Scope data based on project context
    purchase_requests = @project ? @project.purchase_requests : PurchaseRequest.all
    purchase_requests = purchase_requests.includes(:project, :status, :vendor, :user, :capex, :opex)
    
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
    total_estimated_value = purchase_requests.where.not(estimated_price: nil).sum(:estimated_price)
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
    
    # Generate CSV data
    csv_data = generate_purchase_requests_csv(purchase_requests)
    
    {
      summary: {
        total_count: total_count,
        open_count: open_count,
        closed_count: closed_count,
        total_estimated_value: total_estimated_value || 0,
        avg_estimated_value: avg_estimated_value || 0
      },
      status_breakdown: status_breakdown,
      priority_breakdown: priority_breakdown,
      monthly_trend: monthly_trend,
      vendor_stats: vendor_stats,
      recent_requests: purchase_requests.order(created_at: :desc).limit(10),
      csv_data: csv_data,
      project: @project,
      generated_at: Time.current
    }
  end
  
  def generate_vendors_report
    # Scope data based on project context
    base_vendors = @project ? Vendor.available_for_project(@project) : Vendor.all
    
    # Basic statistics (avoid includes for simple counts)
    total_count = base_vendors.count
    active_count = base_vendors.active.count
    global_count = base_vendors.global.count
    project_specific_count = base_vendors.where.not('vendors.project_id' => nil).count
    
    # Purchase request associations (avoid ambiguous project_id)
    vendors_with_requests = base_vendors.joins(:purchase_requests).distinct.count
    vendors_without_requests = total_count - vendors_with_requests
    
    # Activity analysis
    vendor_activity = base_vendors.left_joins(:purchase_requests)
                                 .group('vendors.id', 'vendors.name')
                                 .count('purchase_requests.id')
                                 .sort_by { |_, count| -count }
    
    # Include associations for final vendor list
    vendors = base_vendors.includes(:purchase_requests, :project)
    
    # Project distribution (for global view)
    if @project.nil?
      project_distribution = base_vendors.where.not('vendors.project_id' => nil)
                                        .joins(:project)
                                        .group('projects.name')
                                        .count
    end
    
    # Generate CSV data
    csv_data = generate_vendors_csv(vendors)
    
    {
      summary: {
        total_count: total_count,
        active_count: active_count,
        global_count: global_count,
        project_specific_count: project_specific_count,
        vendors_with_requests: vendors_with_requests,
        vendors_without_requests: vendors_without_requests
      },
      vendor_activity: vendor_activity.first(15),
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
    tpc_codes = tpc_codes.includes(:capex, :opex, :project)
    
    # Basic statistics
    total_count = tpc_codes.count
    active_count = tpc_codes.active.count
    global_count = tpc_codes.global.count
    
    # Usage analysis
    capex_usage = tpc_codes.joins(:capex).group('tpc_codes.tpc_number').count
    opex_usage = tpc_codes.joins(:opex).group('tpc_codes.tpc_number').count
    
    # Financial allocation
    capex_totals = tpc_codes.joins(:capex)
                            .group('tpc_codes.tpc_number')
                            .sum('capex.total_amount')
    
    opex_totals = tpc_codes.joins(:opex)
                           .group('tpc_codes.tpc_number')
                           .sum('opex.total_amount')
    
    # Generate CSV data
    csv_data = generate_tpc_codes_csv(tpc_codes)
    
    {
      summary: {
        total_count: total_count,
        active_count: active_count,
        global_count: global_count,
        with_capex: capex_usage.count,
        with_opex: opex_usage.count
      },
      capex_usage: capex_usage,
      opex_usage: opex_usage,
      capex_totals: capex_totals,
      opex_totals: opex_totals,
      recent_codes: tpc_codes.order(created_at: :desc).limit(10),
      csv_data: csv_data,
      project: @project,
      generated_at: Time.current
    }
  end
  
  def generate_capex_report
    # Scope data based on project context
    capex_items = @project ? @project.capex : Capex.all
    capex_items = capex_items.includes(:project, :tpc_code_record, :purchase_requests)
    
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
    
    # Generate CSV data
    csv_data = generate_capex_csv(capex_items)
    
    {
      summary: {
        total_items: capex_items.count,
        total_value: yearly_totals.values.sum,
        years_covered: years,
        current_year_value: yearly_totals[current_year] || 0
      },
      yearly_totals: yearly_totals,
      quarterly_breakdown: quarterly_breakdown,
      tpc_distribution: tpc_distribution.first(10),
      currency_breakdown: currency_breakdown,
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
        total_value: pr_data[:summary][:total_estimated_value]
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
    
    # Generate combined CSV
    csv_data = generate_overview_csv(pr_data, vendor_data, tpc_data, capex_data, opex_data)
    
    {
      executive_summary: executive_summary,
      total_budget: total_budget,
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
  
  # CSV generation methods
  def generate_purchase_requests_csv(purchase_requests)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['ID', 'Title', 'Project', 'Status', 'Priority', 'Vendor', 'Estimated Price', 'Currency', 'Created', 'Due Date']
      
      purchase_requests.each do |pr|
        csv << [
          pr.id,
          pr.title,
          pr.project&.name,
          pr.status&.name,
          pr.priority,
          pr.vendor&.name,
          pr.estimated_price,
          pr.currency,
          pr.created_at&.strftime('%Y-%m-%d'),
          pr.due_date&.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_vendors_csv(vendors)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['ID', 'Name', 'Vendor ID', 'Email', 'Phone', 'Contact Person', 'Active', 'Scope', 'Purchase Requests Count', 'Created']
      
      vendors.each do |vendor|
        csv << [
          vendor.id,
          vendor.name,
          vendor.vendor_id,
          vendor.email,
          vendor.phone,
          vendor.contact_person,
          vendor.is_active? ? 'Yes' : 'No',
          vendor.project_specific? ? 'Project' : 'Global',
          vendor.purchase_requests.count,
          vendor.created_at&.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_tpc_codes_csv(tpc_codes)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['TPC Number', 'Owner Name', 'Owner Email', 'Description', 'Active', 'Scope', 'CAPEX Items', 'OPEX Items', 'Created']
      
      tpc_codes.each do |tpc|
        csv << [
          tpc.tpc_number,
          tpc.tpc_owner_name,
          tpc.tpc_email,
          tpc.description,
          tpc.is_active? ? 'Yes' : 'No',
          tpc.project_id? ? 'Project' : 'Global',
          tpc.capex.count,
          tpc.opex.count,
          tpc.created_at&.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_capex_csv(capex_items)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['ID', 'Project', 'Year', 'Description', 'TPC Code', 'Total Amount', 'Currency', 'Q1', 'Q2', 'Q3', 'Q4', 'Created']
      
      capex_items.each do |capex|
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
          capex.created_at&.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_opex_csv(opex_items)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['ID', 'Project', 'Year', 'Description', 'TPC Code', 'Category', 'Total Amount', 'Currency', 'Q1', 'Q2', 'Q3', 'Q4', 'Created']
      
      opex_items.each do |opex|
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
          opex.created_at&.strftime('%Y-%m-%d')
        ]
      end
    end
  end
  
  def generate_overview_csv(pr_data, vendor_data, tpc_data, capex_data, opex_data)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Report Section', 'Metric', 'Value']
      
      # Purchase Requests summary
      csv << ['Purchase Requests', 'Total Count', pr_data[:summary][:total_count]]
      csv << ['Purchase Requests', 'Open Count', pr_data[:summary][:open_count]]
      csv << ['Purchase Requests', 'Total Estimated Value', pr_data[:summary][:total_estimated_value]]
      
      # Vendors summary
      csv << ['Vendors', 'Total Count', vendor_data[:summary][:total_count]]
      csv << ['Vendors', 'Active Count', vendor_data[:summary][:active_count]]
      
      # TPC Codes summary
      csv << ['TPC Codes', 'Total Count', tpc_data[:summary][:total_count]]
      csv << ['TPC Codes', 'Active Count', tpc_data[:summary][:active_count]]
      
      # CAPEX summary
      csv << ['CAPEX', 'Total Items', capex_data[:summary][:total_items]]
      csv << ['CAPEX', 'Total Value', capex_data[:summary][:total_value]]
      
      # OPEX summary
      csv << ['OPEX', 'Total Items', opex_data[:summary][:total_items]]
      csv << ['OPEX', 'Total Value', opex_data[:summary][:total_value]]
    end
  end
  
  
  def send_csv_data(csv_data, filename)
    send_data csv_data,
              filename: "#{filename}_#{@project ? @project.identifier + '_' : ''}#{Date.current.strftime('%Y%m%d')}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end
  
  def generate_pdf_report(title, report_data)
    require 'rbpdf'
    
    pdf = RBPDF.new
    pdf.set_creator('Redmine Purchase Requests Plugin')
    pdf.set_author('Purchase Requests System')
    pdf.set_title(title)
    pdf.set_subject(title)
    
    # Set margins
    pdf.set_margins(15, 27, 15)
    pdf.set_header_margin(5)
    pdf.set_footer_margin(10)
    
    # Set auto page breaks
    pdf.set_auto_page_break(true, 25)
    
    # Add page
    pdf.add_page
    
    # Set font
    pdf.set_font('helvetica', 'B', 16)
    
    # Title
    pdf.cell(0, 15, title, 0, 1, 'L')
    
    if @project
      pdf.set_font('helvetica', '', 12)
      pdf.cell(0, 10, "Project: #{@project.name}", 0, 1, 'L')
    end
    
    pdf.set_font('helvetica', '', 10)
    pdf.cell(0, 8, "Generated: #{report_data[:generated_at].strftime('%B %d, %Y at %I:%M %p')}", 0, 1, 'L')
    pdf.ln(5)
    
    # Summary section
    if report_data[:summary]
      pdf.set_font('helvetica', 'B', 14)
      pdf.cell(0, 10, 'Summary', 0, 1, 'L')
      pdf.set_font('helvetica', '', 10)
      
      report_data[:summary].each do |key, value|
        label = key.to_s.humanize
        formatted_value = value.is_a?(Numeric) && value > 1000 ? format_number(value) : value.to_s
        pdf.cell(0, 6, "#{label}: #{formatted_value}", 0, 1, 'L')
      end
      pdf.ln(5)
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
    
    # Budget Distribution Chart
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
    
    capex_opex_ratio = opex_value > 0 ? (capex_value / opex_value).round(2) : "∞"
    pdf.cell(0, 5, "CAPEX to OPEX Ratio: #{capex_opex_ratio}:1", 0, 1, 'L')
    pdf.cell(0, 5, "Average Request Value: $#{format_number(report_data[:purchase_requests][:summary][:avg_estimated_value].round(2))}", 0, 1, 'L')
    pdf.cell(0, 5, "Budget Items per TPC Code: #{tpc_total > 0 ? (total_allocations.to_f / tpc_total).round(1) : 0}", 0, 1, 'L')
  end

  def format_number(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end