# DocxReportHelper — generates DOCX (Office Open XML) report files using only
# the libraries already shipped with Redmine (rubyzip + Nokogiri). No external
# gems required, so no dependency conflicts with Redmine's bundle.
#
# Public API:
#   DocxReportHelper.generate(title, report_data, project:, selected_year:)
#     => binary DOCX blob ready for send_data
#
# The DOCX format is a ZIP archive of XML parts. This builder produces a
# minimal, valid DOCX containing styled headings, paragraphs, and tables
# with header rows, zebra striping, and an accent color matching the
# plugin's pr- design system.
require 'tempfile'
require 'zip'
require 'nokogiri'

module DocxReportHelper
  # Brand colors matching the plugin's pr- design system (hex, no leading #).
  ACCENT_COLOR    = '6B4FC7'.freeze
  INK_COLOR       = '1F2330'.freeze
  MUTED_COLOR     = '5C6573'.freeze
  HEADER_BG_COLOR = 'F4F3F9'.freeze
  ZEBRA_BG_COLOR  = 'FAFAFB'.freeze

  XMLNS_W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'.freeze

  module_function

  def available?
    true
  end

  # Top-level entry point. Returns a binary DOCX blob.
  def generate(title, report_data, project: nil, selected_year: nil)
    body_xml = build_document_xml(title, report_data, project: project, selected_year: selected_year)
    package_docx(body_xml)
  end

  # ------------------------------------------------------------------
  # ZIP packaging
  # ------------------------------------------------------------------

  def package_docx(document_xml)
    tmp = Tempfile.new(['report', '.docx'])
    tmp.binmode
    tmp.close

    Zip::File.open(tmp.path, Zip::File::CREATE) do |zip|
      zip.get_output_stream('[Content_Types].xml')          { |io| io.write content_types_xml }
      zip.get_output_stream('_rels/.rels')                   { |io| io.write package_rels_xml }
      zip.get_output_stream('word/_rels/document.xml.rels')  { |io| io.write document_rels_xml }
      zip.get_output_stream('word/styles.xml')               { |io| io.write styles_xml }
      zip.get_output_stream('word/document.xml')             { |io| io.write document_xml }
    end

    blob = File.binread(tmp.path)
    File.unlink(tmp.path) rescue nil
    blob
  end

  # ------------------------------------------------------------------
  # Document body
  # ------------------------------------------------------------------

  def build_document_xml(title, report_data, project:, selected_year:)
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml['w'].document('xmlns:w' => XMLNS_W) do
        xml['w'].body do
          add_cover(xml, title, project: project, selected_year: selected_year, generated_at: report_data[:generated_at])
          add_summary_section(xml, report_data)

          case title
          when 'Purchase Requests Report'  then add_purchase_requests_section(xml, report_data)
          when 'Vendors Report'            then add_vendors_section(xml, report_data)
          when 'TPC Codes Report'          then add_tpc_codes_section(xml, report_data)
          when 'CAPEX Report'              then add_capex_section(xml, report_data)
          when 'OPEX Report'               then add_opex_section(xml, report_data)
          when 'Executive Overview Report' then add_overview_section(xml, report_data)
          end

          add_footer(xml, title)

          # Section properties (required by Word)
          xml['w'].sectPr do
            xml['w'].pgSz('w:w' => '12240', 'w:h' => '15840')
            xml['w'].pgMar('w:top' => '1080', 'w:right' => '1080', 'w:bottom' => '1080', 'w:left' => '1080', 'w:header' => '720', 'w:footer' => '720', 'w:gutter' => '0')
            xml['w'].cols('w:space' => '720')
          end
        end
      end
    end
    builder.to_xml
  end

  # ------------------------------------------------------------------
  # Building blocks (paragraph, run, heading, table)
  # ------------------------------------------------------------------

  def paragraph(xml, text, style: nil, bold: false, color: nil, size: nil, italic: false)
    xml['w'].p do
      xml['w'].pPr do
        xml['w'].pStyle('w:val' => style) if style
      end
      run(xml, text, bold: bold, color: color, size: size, italic: italic)
    end
  end

  def run(xml, text, bold: false, color: nil, size: nil, italic: false)
    xml['w'].r do
      xml['w'].rPr do
        xml['w'].b           if bold
        xml['w'].i           if italic
        xml['w'].color('w:val' => color)     if color
        xml['w'].sz('w:val' => size.to_s)    if size
        xml['w'].szCs('w:val' => size.to_s)  if size
      end
      xml['w'].t(text.to_s, 'xml:space' => 'preserve')
    end
  end

  def heading(xml, text, level:)
    style = "Heading#{level}"
    paragraph(xml, text, style: style)
  end

  def horizontal_rule(xml)
    xml['w'].p do
      xml['w'].pPr do
        xml['w'].pBdr do
          xml['w'].bottom('w:val' => 'single', 'w:sz' => '6', 'w:space' => '1', 'w:color' => MUTED_COLOR)
        end
      end
    end
  end

  def blank_paragraph(xml)
    xml['w'].p
  end

  # Render a 2-D array of strings as a Word table with header row.
  def table(xml, rows)
    return if rows.nil? || rows.empty?

    col_count = rows.first.size
    col_width = (9000 / col_count).to_s  # twentieths of a point, 9000 ~ 6.25"

    xml['w'].tbl do
      xml['w'].tblPr do
        xml['w'].tblW('w:w' => '9000', 'w:type' => 'dxa')
        xml['w'].tblBorders do
          %w[top left bottom right insideH insideV].each do |side|
            xml['w'].send(side, 'w:val' => 'single', 'w:sz' => '4', 'w:color' => 'D3D7DF')
          end
        end
        xml['w'].tblLayout('w:type' => 'fixed')
      end
      xml['w'].tblGrid do
        col_count.times { xml['w'].gridCol('w:w' => col_width) }
      end

      rows.each_with_index do |row, row_idx|
        is_header = (row_idx == 0)
        is_zebra  = (!is_header && row_idx.odd?)
        bg_color  = is_header ? HEADER_BG_COLOR : (is_zebra ? ZEBRA_BG_COLOR : nil)

        xml['w'].tr do
          row.each do |cell_text|
            xml['w'].tc do
              xml['w'].tcPr do
                xml['w'].tcW('w:w' => col_width, 'w:type' => 'dxa')
                xml['w'].shd('w:val' => 'clear', 'w:color' => 'auto', 'w:fill' => bg_color) if bg_color
              end
              xml['w'].p do
                xml['w'].pPr { xml['w'].spacing('w:before' => '40', 'w:after' => '40') }
                run(xml, cell_text, bold: is_header, color: (is_header ? ACCENT_COLOR : nil), size: (is_header ? '20' : '20'))
              end
            end
          end
        end
      end
    end
    blank_paragraph(xml)
  end

  # ------------------------------------------------------------------
  # Cover, summary, footer
  # ------------------------------------------------------------------

  def add_cover(xml, title, project:, selected_year:, generated_at:)
    paragraph(xml, title, bold: true, color: ACCENT_COLOR, size: '44')
    if project
      paragraph(xml, "Project: #{project.name}", bold: true, color: INK_COLOR, size: '26')
    end
    scope_label = selected_year.present? ? "Year #{selected_year}" : 'All Years'
    paragraph(xml, scope_label, color: MUTED_COLOR, size: '22')
    if generated_at
      paragraph(xml, "Generated: #{generated_at.strftime('%B %d, %Y at %I:%M %p')}", color: MUTED_COLOR, size: '18')
    end
    paragraph(xml, "Generated by: #{User.current.name} (#{User.current.mail})", color: MUTED_COLOR, size: '18', italic: true)
    horizontal_rule(xml)
  end

  def add_summary_section(xml, report_data)
    return unless report_data[:summary].is_a?(Hash) && report_data[:summary].any?

    heading(xml, 'Summary', level: 2)
    rows = [['Metric', 'Value']]
    report_data[:summary].each do |key, value|
      label = humanize_key(key)
      rows << [label, format_value(value)]
    end
    table(xml, rows)
  end

  def add_footer(xml, title)
    horizontal_rule(xml)
    paragraph(xml, "#{title} · Generated by Redmine Purchase Requests plugin", color: MUTED_COLOR, size: '18', italic: true)
  end

  # ------------------------------------------------------------------
  # Per-report sections
  # ------------------------------------------------------------------

  def add_kv_table(xml, heading_text, hash, value_formatter: nil)
    return if hash.nil? || hash.empty?

    heading(xml, heading_text, level: 3)
    rows = [['Item', 'Value']]
    hash.each do |k, v|
      formatted = value_formatter ? value_formatter.call(v) : format_value(v)
      rows << [k.to_s, formatted]
    end
    table(xml, rows)
  end

  def add_simple_table(xml, heading_text, header_row, data_rows)
    return if data_rows.nil? || data_rows.empty?

    heading(xml, heading_text, level: 3)
    table(xml, [header_row] + data_rows)
  end

  def add_purchase_requests_section(xml, data)
    add_kv_table(xml, 'Status Distribution',     data[:status_breakdown])
    add_kv_table(xml, 'Priority Distribution',   data[:priority_breakdown])
    add_kv_table(xml, 'Budget Source Breakdown', data[:budget_source_breakdown])
    add_kv_table(xml, 'Budget Source Value',     data[:budget_source_value],
                 value_formatter: ->(v) { format_currency(v) })

    if data[:requester_breakdown].is_a?(Array) && data[:requester_breakdown].any?
      rows = data[:requester_breakdown].first(10).map { |r| [r[:name].to_s, r[:count].to_s] }
      add_simple_table(xml, 'Top Requesters', ['Requester', 'Requests'], rows)
    end

    if data[:tpc_distribution].is_a?(Hash) && data[:tpc_distribution].any?
      add_kv_table(xml, 'Top TPC Codes (by Request Count)', data[:tpc_distribution])
    end
  end

  def add_vendors_section(xml, data)
    add_kv_table(xml, 'Vendor Activity',       data[:activity_breakdown])  if data[:activity_breakdown]
    add_kv_table(xml, 'Top Vendors',           data[:top_vendors])         if data[:top_vendors]
    add_kv_table(xml, 'Vendors by Country',    data[:country_breakdown])   if data[:country_breakdown]
  end

  def add_tpc_codes_section(xml, data)
    add_kv_table(xml, 'TPC Code Status',           data[:status_breakdown])      if data[:status_breakdown]
    add_kv_table(xml, 'Department Distribution',   data[:department_breakdown])  if data[:department_breakdown]

    if data[:utilization].is_a?(Array) && data[:utilization].any?
      rows = data[:utilization].first(20).map do |tpc|
        [tpc[:tpc_code].to_s, tpc[:owner].to_s, tpc[:department].to_s,
         format_currency(tpc[:total_cost] || 0), tpc[:request_count].to_s]
      end
      add_simple_table(xml, 'Top TPC Codes by Cost',
                       ['TPC Code', 'Owner', 'Department', 'Total Cost', 'Requests'], rows)
    end
  end

  def add_capex_section(xml, data)
    add_kv_table(xml, 'Yearly Totals',         data[:yearly_totals],       value_formatter: ->(v) { format_currency(v) })
    add_kv_table(xml, 'Quarterly Breakdown',   data[:quarterly_breakdown], value_formatter: ->(v) { format_currency(v) })
    add_kv_table(xml, 'Currency Breakdown',    data[:currency_breakdown],  value_formatter: ->(v) { format_currency(v) })
    if data[:tpc_distribution].is_a?(Array) && data[:tpc_distribution].any?
      rows = data[:tpc_distribution].first(15).map { |code, amt| [code.to_s, format_currency(amt)] }
      add_simple_table(xml, 'CAPEX by TPC Code', ['TPC Code', 'Amount'], rows)
    end
  end

  def add_opex_section(xml, data)
    add_kv_table(xml, 'Yearly Totals',         data[:yearly_totals],       value_formatter: ->(v) { format_currency(v) })
    add_kv_table(xml, 'Quarterly Breakdown',   data[:quarterly_breakdown], value_formatter: ->(v) { format_currency(v) })
    add_kv_table(xml, 'Category Breakdown',    data[:category_breakdown],  value_formatter: ->(v) { format_currency(v) })
    add_kv_table(xml, 'Currency Breakdown',    data[:currency_breakdown],  value_formatter: ->(v) { format_currency(v) })
  end

  def add_overview_section(xml, data)
    if data[:executive_summary].is_a?(Hash)
      data[:executive_summary].each do |group_key, group_hash|
        next unless group_hash.is_a?(Hash) && group_hash.any?
        add_kv_table(xml, humanize_key(group_key), group_hash)
      end
    end
  end

  # ------------------------------------------------------------------
  # Formatting helpers
  # ------------------------------------------------------------------

  def humanize_key(key)
    key.to_s.tr('_', ' ').split.map(&:capitalize).join(' ')
  end

  def format_value(value)
    return '—' if value.nil?
    return value.size.to_s if value.is_a?(Array)
    return value.to_s.size.to_s if value.is_a?(Hash)
    if value.is_a?(Numeric)
      if value.is_a?(Integer)
        value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      elsif value.abs >= 1000
        "%.2f" % value
      else
        value.to_s
      end
    else
      value.to_s
    end
  end

  def format_currency(value)
    return '—' if value.nil?
    num = value.to_f
    if num.abs >= 1_000_000
      "$#{(num / 1_000_000).round(2)}M"
    elsif num.abs >= 1_000
      "$#{(num / 1_000).round(1)}K"
    else
      "$#{num.round(2)}"
    end
  end

  # ------------------------------------------------------------------
  # Static OOXML parts
  # ------------------------------------------------------------------

  def content_types_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
      </Types>
    XML
  end

  def package_rels_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
      </Relationships>
    XML
  end

  def document_rels_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
      </Relationships>
    XML
  end

  def styles_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:docDefaults>
          <w:rPrDefault>
            <w:rPr>
              <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
              <w:sz w:val="22"/>
              <w:szCs w:val="22"/>
              <w:color w:val="#{INK_COLOR}"/>
            </w:rPr>
          </w:rPrDefault>
          <w:pPrDefault>
            <w:pPr>
              <w:spacing w:after="120" w:line="276" w:lineRule="auto"/>
            </w:pPr>
          </w:pPrDefault>
        </w:docDefaults>
        <w:style w:type="paragraph" w:styleId="Heading1">
          <w:name w:val="heading 1"/>
          <w:basedOn w:val="Normal"/>
          <w:next w:val="Normal"/>
          <w:pPr>
            <w:spacing w:before="240" w:after="120"/>
            <w:outlineLvl w:val="0"/>
          </w:pPr>
          <w:rPr>
            <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
            <w:b/>
            <w:color w:val="#{ACCENT_COLOR}"/>
            <w:sz w:val="36"/>
          </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading2">
          <w:name w:val="heading 2"/>
          <w:basedOn w:val="Normal"/>
          <w:next w:val="Normal"/>
          <w:pPr>
            <w:spacing w:before="280" w:after="120"/>
            <w:outlineLvl w:val="1"/>
          </w:pPr>
          <w:rPr>
            <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
            <w:b/>
            <w:color w:val="#{INK_COLOR}"/>
            <w:sz w:val="28"/>
          </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading3">
          <w:name w:val="heading 3"/>
          <w:basedOn w:val="Normal"/>
          <w:next w:val="Normal"/>
          <w:pPr>
            <w:spacing w:before="200" w:after="100"/>
            <w:outlineLvl w:val="2"/>
          </w:pPr>
          <w:rPr>
            <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
            <w:b/>
            <w:color w:val="#{MUTED_COLOR}"/>
            <w:sz w:val="24"/>
          </w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
          <w:name w:val="Normal"/>
        </w:style>
      </w:styles>
    XML
  end
end
