#!/usr/bin/env ruby

# Test CAPEX functionality
require_relative '../../config/environment'

puts "=== CAPEX Functionality Test ==="
puts "Date: #{Date.current}"
puts

begin
  # Check if tables exist
  puts "1. Checking database tables..."
  if ActiveRecord::Base.connection.table_exists?('capex')
    puts "✓ CAPEX table exists"
    capex_columns = ActiveRecord::Base.connection.columns('capex').map(&:name)
    puts "  Columns: #{capex_columns.join(', ')}"
  else
    puts "✗ CAPEX table missing"
  end

  if ActiveRecord::Base.connection.table_exists?('purchase_requests')
    pr_columns = ActiveRecord::Base.connection.columns('purchase_requests').map(&:name)
    puts "✓ Purchase requests table exists"
    puts "  Has capex_id: #{pr_columns.include?('capex_id') ? 'YES' : 'NO'}"
  else
    puts "✗ Purchase requests table missing"
  end

  puts

  # Check if models can be loaded
  puts "2. Checking model classes..."
  begin
    capex_class = Capex
    puts "✓ Capex model can be loaded: #{capex_class}"
  rescue => e
    puts "✗ Capex model error: #{e.message}"
  end

  begin
    pr_class = PurchaseRequest
    puts "✓ PurchaseRequest model can be loaded: #{pr_class}"
  rescue => e
    puts "✗ PurchaseRequest model error: #{e.message}"
  end

  puts

  # Test basic CAPEX operations if possible
  puts "3. Testing basic CAPEX operations..."
  
  # Find a project to test with
  project = Project.first
  if project
    puts "✓ Found test project: #{project.name} (ID: #{project.id})"
    
    # Try to create a CAPEX entry
    begin
      capex = Capex.new(
        project_id: project.id,
        year: 2025,
        description: "Test CAPEX Entry",
        tpc_code: "TEST001",
        total_amount: 100000,
        currency: "USD",
        q1_amount: 25000,
        q2_amount: 25000,
        q3_amount: 25000,
        q4_amount: 25000
      )
      
      if capex.valid?
        puts "✓ CAPEX validation passed"
        # Don't actually save to avoid test data
        puts "  Would create: #{capex.description} for #{capex.total_amount} #{capex.currency}"
      else
        puts "✗ CAPEX validation failed: #{capex.errors.full_messages.join(', ')}"
      end
    rescue => e
      puts "✗ CAPEX creation error: #{e.message}"
    end
  else
    puts "✗ No projects found for testing"
  end

  puts

  # Check plugin registration
  puts "4. Checking plugin registration..."
  plugin = Redmine::Plugin.find(:redmine_purchase_requests)
  if plugin
    puts "✓ Plugin registered: #{plugin.name}"
    puts "  Version: #{plugin.version}"
    puts "  Author: #{plugin.author}"
  else
    puts "✗ Plugin not registered"
  end

rescue => e
  puts "Fatal error: #{e.message}"
  puts e.backtrace.first(5)
end

puts
puts "=== Test Complete ==="
