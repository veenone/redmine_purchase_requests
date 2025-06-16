#!/usr/bin/env ruby

# Simple test that writes results to a file
require_relative '../../config/environment'

File.open('/tmp/capex_test_results.txt', 'w') do |f|
  f.puts "=== CAPEX Test Results ==="
  f.puts "Time: #{Time.current}"
  f.puts

  begin
    # Check tables
    f.puts "Checking tables..."
    f.puts "CAPEX table exists: #{ActiveRecord::Base.connection.table_exists?('capex')}"
    f.puts "Purchase requests table exists: #{ActiveRecord::Base.connection.table_exists?('purchase_requests')}"
    
    if ActiveRecord::Base.connection.table_exists?('purchase_requests')
      columns = ActiveRecord::Base.connection.columns('purchase_requests').map(&:name)
      f.puts "Purchase requests has capex_id: #{columns.include?('capex_id')}"
    end
    
    # Check models
    f.puts
    f.puts "Checking models..."
    
    begin
      Capex
      f.puts "Capex model: OK"
    rescue => e
      f.puts "Capex model error: #{e.message}"
    end
    
    begin
      PurchaseRequest
      f.puts "PurchaseRequest model: OK"
    rescue => e
      f.puts "PurchaseRequest model error: #{e.message}"
    end
    
    # Check plugin
    f.puts
    f.puts "Checking plugin..."
    plugin = Redmine::Plugin.find(:redmine_purchase_requests)
    if plugin
      f.puts "Plugin: #{plugin.name} v#{plugin.version}"
    else
      f.puts "Plugin: Not found"
    end
    
  rescue => e
    f.puts "Error: #{e.message}"
    f.puts e.backtrace.first(3).join("\n")
  end
  
  f.puts
  f.puts "=== End Test ==="
end

puts "Test completed. Results written to /tmp/capex_test_results.txt"
