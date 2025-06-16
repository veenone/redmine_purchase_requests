#!/usr/bin/env ruby
# Test script to verify CAPEX functionality

# Load Rails environment
require_relative '../../../config/environment'

puts "Testing CAPEX functionality..."

begin
  # Test 1: Check if tables exist
  puts "1. Checking if tables exist..."
  capex_exists = ActiveRecord::Base.connection.table_exists?('capex')
  puts "   CAPEX table exists: #{capex_exists}"
  
  purchase_requests_has_capex = ActiveRecord::Base.connection.column_exists?(:purchase_requests, :capex_id)
  puts "   Purchase requests has capex_id: #{purchase_requests_has_capex}"
  
  # Test 2: Try to load Capex model
  puts "2. Testing Capex model..."
  capex_model = Capex.new
  puts "   Capex model loaded successfully: #{capex_model.class.name}"
  
  # Test 3: Check if we can create a project and link to CAPEX
  puts "3. Testing project association..."
  project = Project.first
  if project
    puts "   Found project: #{project.name}"
    puts "   Project has capex association: #{project.respond_to?(:capex)}"
  else
    puts "   No projects found in database"
  end
  
  # Test 4: Check purchase request model
  puts "4. Testing PurchaseRequest model..."
  pr = PurchaseRequest.new
  puts "   PurchaseRequest has capex association: #{pr.respond_to?(:capex)}"
  puts "   PurchaseRequest has capex_id attribute: #{pr.respond_to?(:capex_id)}"
  
  puts "\nCAPEX functionality test completed successfully!"
  
rescue => e
  puts "Error testing CAPEX functionality: #{e.message}"
  puts e.backtrace.first(5)
end
