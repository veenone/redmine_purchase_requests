#!/usr/bin/env ruby

# CAPEX Implementation Final Validation Test
# This script validates all the key components we've implemented

puts "=== CAPEX Implementation Final Validation Test ==="
puts "Date: #{Time.now}"
puts

# Test 1: Check if key files exist
puts "1. Checking key files exist..."
files_to_check = [
  'app/controllers/capex_controller.rb',
  'app/helpers/capex_helper.rb',
  'app/views/capex/dashboard.html.erb',
  'app/views/settings/_purchase_request_capex.html.erb',
  'lib/settings_controller_patch.rb',
  'config/locales/en.yml'
]

files_to_check.each do |file|
  if File.exist?(file)
    puts "  ✓ #{file}"
  else
    puts "  ✗ #{file} MISSING"
  end
end
puts

# Test 2: Check syntax of Ruby files
puts "2. Checking Ruby file syntax..."
ruby_files = [
  'app/controllers/capex_controller.rb',
  'app/helpers/capex_helper.rb',
  'lib/settings_controller_patch.rb'
]

ruby_files.each do |file|
  if File.exist?(file)
    result = `ruby -c #{file} 2>&1`
    if $?.success?
      puts "  ✓ #{file} - syntax OK"
    else
      puts "  ✗ #{file} - syntax error: #{result.strip}"
    end
  end
end
puts

# Test 3: Check for ApexCharts dependencies (should be none)
puts "3. Checking for ApexCharts dependencies (should be removed)..."
apexcharts_files = `find . -name "*.erb" -exec grep -l "apexcharts\\|ApexCharts" {} \\; 2>/dev/null`.strip.split("\n")
if apexcharts_files.empty?
  puts "  ✓ No ApexCharts dependencies found"
else
  puts "  ✗ ApexCharts still found in:"
  apexcharts_files.each { |f| puts "    - #{f}" }
end
puts

# Test 4: Check for key features in dashboard
puts "4. Checking dashboard features..."
dashboard_file = 'app/views/capex/dashboard.html.erb'
if File.exist?(dashboard_file)
  content = File.read(dashboard_file)
  
  features = {
    'TPC Grouping' => 'tpc_grouping',
    'Currency Conversion' => 'convert_capex_currency',
    'Native Charts' => 'class="chart-container"',
    'Year Selection' => '@current_year',
    'Exchange Rate Support' => '@use_exchange_rates'
  }
  
  features.each do |feature_name, search_term|
    if content.include?(search_term)
      puts "  ✓ #{feature_name} implementation found"
    else
      puts "  ✗ #{feature_name} implementation missing"
    end
  end
else
  puts "  ✗ Dashboard file missing"
end
puts

# Test 5: Check translation labels
puts "5. Checking translation labels..."
locale_file = 'config/locales/en.yml'
if File.exist?(locale_file)
  content = File.read(locale_file)
  
  key_labels = [
    'label_capex_settings',
    'label_budget_by_tpc_code',
    'label_capex_exchange_rates',
    'label_tpc_code_grouping',
    'text_capex_use_exchange_rates_info'
  ]
  
  key_labels.each do |label|
    if content.include?(label)
      puts "  ✓ #{label}"
    else
      puts "  ✗ #{label} missing"
    end
  end
else
  puts "  ✗ Locale file missing"
end
puts

# Test 6: Check settings controller patch
puts "6. Checking settings controller patch..."
patch_file = 'lib/settings_controller_patch.rb'
if File.exist?(patch_file)
  content = File.read(patch_file)
  if content.include?('capex_exchange_rate_') && content.include?('year_exchange_rates')
    puts "  ✓ Settings controller patch includes year-specific exchange rate handling"
  else
    puts "  ✗ Settings controller patch missing year-specific exchange rate handling"
  end
else
  puts "  ✗ Settings controller patch missing"
end
puts

# Test 7: Check helper methods
puts "7. Checking helper methods..."
helper_file = 'app/helpers/capex_helper.rb'
if File.exist?(helper_file)
  content = File.read(helper_file)
  
  methods = [
    'convert_capex_currency',
    'capex_currency_symbol',
    'default_capex_currency',
    'capex_use_exchange_rates?'
  ]
  
  methods.each do |method|
    if content.include?("def #{method}")
      puts "  ✓ #{method} method found"
    else
      puts "  ✗ #{method} method missing"
    end
  end
else
  puts "  ✗ Helper file missing"
end
puts

puts "=== Test Complete ==="
puts "Next steps:"
puts "1. Test at http://172.17.86.242/"
puts "2. Verify CAPEX dashboard functionality"
puts "3. Test year-specific exchange rate configuration"
puts "4. Validate TPC code grouping display"
puts "5. Confirm native charts are working"
