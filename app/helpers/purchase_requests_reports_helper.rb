module PurchaseRequestsReportsHelper
  # Build the query string for an export link, preserving the current year filter.
  # Usage in views:  "<%= report_export_params(:pdf) %>"  =>  "format=pdf&year=2026"
  def report_export_params(format)
    parts = ["format=#{format}"]
    parts << "year=#{@selected_year}" if @selected_year.present?
    parts.join('&')
  end

  # Human-readable year-filter suffix for titles ("(2026)" or "" when all years).
  def report_year_suffix
    @selected_year.present? ? " (#{@selected_year})" : ''
  end

  # Year-aware "Generated" line used by every report.
  def report_generated_line(generated_at)
    scope = @selected_year.present? ? "Year #{@selected_year}" : 'All Years'
    "Generated #{generated_at.strftime('%B %d, %Y at %I:%M %p')} · Scope: #{scope}"
  end
end
