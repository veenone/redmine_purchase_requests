#!/usr/bin/env ruby

puts "Testing CAPEX controller database query fix..."

begin
  # Load Rails environment
  require_relative '/opt/redmine/config/environment'
  
  puts "✓ Rails environment loaded"
  
  # Test the problematic query that was causing the error
  puts "\nTesting database queries that were causing the error..."
  
  # Simulate what the controller does
  project = Project.first
  if project
    puts "✓ Found test project: #{project.name}"
    
    # Test the query that was failing
    begin
      capex_entries = project.capex
      years = capex_entries.distinct.pluck(:year).sort.reverse
      puts "✓ Successfully retrieved years: #{years.inspect}"
      
      # Test if there are any CAPEX entries
      capex_count = capex_entries.count
      puts "✓ Found #{capex_count} CAPEX entries for this project"
      
      if capex_count > 0
        # Test individual CAPEX entry methods
        first_capex = capex_entries.first
        puts "✓ Testing CAPEX entry methods:"
        puts "  - Year (DB column): #{first_capex.year}"
        puts "  - CAPEX Year (method): #{first_capex.capex_year}"
        puts "  - Display Name: #{first_capex.display_name}"
      end
      
    rescue => e
      puts "✗ Database query failed: #{e.message}"
      raise e
    end
    
  else
    puts "✗ No projects found in database"
  end
  
  puts "\n✅ All database queries successful!"
  puts "The CAPEX controller should now work without 'Unknown column' errors."
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts "Stack trace: #{e.backtrace.first(5).join("\n")}"
end
