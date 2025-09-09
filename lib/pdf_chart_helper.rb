# PDF Chart Helper for generating charts in PDF reports
class PdfChartHelper
  
  def self.generate_bar_chart(pdf, data, options = {})
    return unless data.any?
    
    # Default options
    opts = {
      width: 400,
      height: 200,
      title: 'Chart',
      x_axis_title: '',
      y_axis_title: '',
      position: :center
    }.merge(options)
    
    # Convert data to prawn-graph format
    series = []
    colors = ['FF6B6B', '4ECDC4', '45B7D1', '96CEB4', 'FECA57', 'FF9FF3']
    
    if data.is_a?(Hash)
      # Single series data
      series << create_series_from_hash(data, opts[:title], colors[0])
    elsif data.is_a?(Array) && data.first.is_a?(Hash)
      # Multiple series data
      data.each_with_index do |series_data, index|
        color = colors[index % colors.length]
        title = series_data[:title] || "Series #{index + 1}"
        values = series_data[:data] || series_data[:values]
        series << create_series_from_values(values, title, color)
      end
    end
    
    return if series.empty?
    
    # Since we're using RBPDF (not Prawn), we need to check if prawn-graph is available
    # and convert to Prawn if possible, otherwise use fallback
    begin
      require 'prawn/graph'
      
      # prawn-graph requires Prawn, but we're using RBPDF
      # For now, use enhanced ASCII fallback until we can implement RBPDF charts
      add_enhanced_ascii_chart_fallback(pdf, data, opts)
      
    rescue LoadError
      # Fallback to ASCII representation if prawn-graph not available
      add_enhanced_ascii_chart_fallback(pdf, data, opts)
    rescue => e
      Rails.logger.error "PDF Chart Error: #{e.message}" if defined?(Rails)
      add_enhanced_ascii_chart_fallback(pdf, data, opts)
    end
  end
  
  def self.generate_line_chart(pdf, data, options = {})
    options[:type] = :line
    generate_bar_chart(pdf, data, options)
  end
  
  def self.generate_pie_chart(pdf, data, options = {})
    return unless data.is_a?(Hash) && data.any?
    
    opts = {
      width: 300,
      height: 300,
      title: 'Distribution'
    }.merge(options)
    
    # Since we're using RBPDF, use enhanced table representation
    add_enhanced_pie_chart_fallback(pdf, data, opts)
  end
  
  private
  
  def self.create_series_from_hash(data, title, color)
    labels = data.keys.map(&:to_s)
    values = data.values.map(&:to_f)
    
    # prawn-graph series format
    {
      data: values,
      title: title,
      color: color,
      labels: labels
    }
  end
  
  def self.create_series_from_values(values, title, color)
    {
      data: values.map(&:to_f),
      title: title,
      color: color
    }
  end
  
  def self.add_enhanced_ascii_chart_fallback(pdf, data, opts)
    # Enhanced ASCII chart with professional table layout
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 8, opts[:title], 0, 1, 'L') if opts[:title]
    pdf.ln(3)
    
    if data.is_a?(Hash) && data.any?
      # Create professional table header
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(80, 6, 'Category', 1, 0, 'C')
      pdf.cell(40, 6, 'Value', 1, 0, 'C')
      pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
      pdf.cell(40, 6, 'Visual', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      max_value = data.values.max.to_f
      total_value = data.values.sum.to_f
      
      data.each do |label, value|
        bar_length = max_value > 0 ? (value.to_f / max_value * 10).to_i : 0
        bars = '#' * bar_length + '.' * (10 - bar_length)
        percentage = total_value > 0 ? ((value.to_f / total_value) * 100).round(1) : 0
        
        # Truncate long labels
        display_label = label.to_s.length > 25 ? "#{label.to_s[0, 22]}..." : label.to_s
        
        pdf.cell(80, 5, display_label, 1, 0, 'L')
        pdf.cell(40, 5, value.to_s, 1, 0, 'R')
        pdf.cell(30, 5, "#{percentage}%", 1, 0, 'C')
        pdf.cell(40, 5, bars, 1, 1, 'L')
      end
    else
      pdf.set_font('helvetica', '', 9)
      pdf.cell(0, 5, 'No data available for chart', 0, 1, 'L')
    end
    
    pdf.ln(8)
  end
  
  def self.add_enhanced_pie_chart_fallback(pdf, data, opts)
    # Enhanced pie chart representation with circular indicators
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 8, opts[:title], 0, 1, 'C') if opts[:title]
    pdf.ln(3)
    
    if data.any?
      # Create professional table with circular indicators
      pdf.set_font('helvetica', 'B', 9)
      pdf.cell(20, 6, 'Color', 1, 0, 'C')
      pdf.cell(80, 6, 'Category', 1, 0, 'C')
      pdf.cell(40, 6, 'Value', 1, 0, 'C')
      pdf.cell(30, 6, 'Percentage', 1, 0, 'C')
      pdf.cell(20, 6, 'Arc', 1, 1, 'C')
      
      pdf.set_font('helvetica', '', 8)
      total = data.values.sum.to_f
      colors = ['*', '+', 'o', 'x', '%', '&']  # Using ASCII symbols as color indicators
      color_names = ['Red', 'Blue', 'Green', 'Orange', 'Purple', 'Cyan']
      
      data.each_with_index do |(label, value), index|
        percentage = total > 0 ? ((value.to_f / total) * 100).round(1) : 0
        arc_representation = '-' * (percentage / 5).to_i  # Visual arc representation
        color_indicator = colors[index % colors.length]
        color_name = color_names[index % color_names.length]
        
        # Truncate long labels
        display_label = label.to_s.length > 25 ? "#{label.to_s[0, 22]}..." : label.to_s
        
        pdf.cell(20, 5, color_indicator, 1, 0, 'C')
        pdf.cell(80, 5, display_label, 1, 0, 'L')
        pdf.cell(40, 5, value.to_s, 1, 0, 'R')
        pdf.cell(30, 5, "#{percentage}%", 1, 0, 'C')
        pdf.cell(20, 5, arc_representation.length > 0 ? arc_representation[0, 4] : '-', 1, 1, 'C')
      end
    else
      pdf.set_font('helvetica', '', 9)
      pdf.cell(0, 5, 'No data available for pie chart', 0, 1, 'C')
    end
    
    pdf.ln(8)
  end
end