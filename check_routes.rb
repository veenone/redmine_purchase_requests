#!/usr/bin/env ruby

puts "Checking Rails routes for CAPEX..."

begin
  # Load Rails environment
  require_relative '/opt/redmine/config/environment'
  
  puts "✓ Rails environment loaded"
  
  # Check available routes
  puts "\nChecking available CAPEX routes..."
  
  routes = Rails.application.routes.routes
  capex_routes = routes.select { |r| r.path.spec.to_s.include?('capex') }
  
  puts "Found #{capex_routes.length} CAPEX-related routes:"
  capex_routes.each do |route|
    puts "  #{route.verb.ljust(8)} #{route.path.spec.to_s.ljust(40)} #{route.name}"
  end
  
  # Test if route helpers exist
  puts "\nTesting route helper methods..."
  
  test_helpers = [
    'project_capex_index_path',
    'project_capexes_path', 
    'project_capex_path',
    'new_project_capex_path',
    'edit_project_capex_path'
  ]
  
  # Create a dummy object to test route helpers
  include Rails.application.routes.url_helpers
  
  test_helpers.each do |helper|
    begin
      if respond_to?(helper)
        puts "  ✓ #{helper} - available"
      else
        puts "  ✗ #{helper} - not available"
      end
    rescue => e
      puts "  ✗ #{helper} - error: #{e.message}"
    end
  end
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts "Stack trace: #{e.backtrace.first(3).join("\n")}"
end
