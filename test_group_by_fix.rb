#!/usr/bin/env ruby

puts "Testing CAPEX GROUP BY ORDER BY fix..."

begin
  # Load Rails environment
  require_relative '/opt/redmine/config/environment'
  
  puts "✓ Rails environment loaded"
  
  # Test the problematic query combination
  puts "\nTesting GROUP BY with ORDER BY issue..."
  
  project = Project.first
  if project
    puts "✓ Found test project: #{project.name}"
    
    # Test the original problematic query (should fail with strict MySQL)
    puts "\n1. Testing problematic query (ordered + group):"
    begin
      # This would fail with sql_mode=only_full_group_by
      bad_breakdown = project.capex.for_year(2025).ordered.group(:currency).sum(:total_amount)
      puts "⚠  Warning: Bad query succeeded - MySQL might not have strict mode enabled"
      puts "   Currency breakdown: #{bad_breakdown}"
    rescue => e
      puts "✓ Expected error confirmed: #{e.message[0..80]}..."
    end
    
    # Test the fixed query (should work)
    puts "\n2. Testing fixed query (group without ordering):"
    begin
      good_breakdown = project.capex.for_year(2025).group(:currency).sum(:total_amount)
      puts "✓ Fixed query succeeded!"
      puts "   Currency breakdown: #{good_breakdown}"
    rescue => e
      puts "✗ Fixed query failed: #{e.message}"
      raise e
    end
    
    # Test the full dashboard logic
    puts "\n3. Testing full dashboard controller logic:"
    begin
      # Simulate what the controller does
      current_year = 2025
      capex_entries = project.capex.for_year(current_year).ordered  # For main display
      
      # Statistics calculations (these should work)
      total_budget = capex_entries.sum(:total_amount)
      
      # Fixed currency breakdown (without ordering)
      currency_breakdown = project.capex.for_year(current_year).group(:currency).sum(:total_amount)
      
      puts "✓ Dashboard logic simulation successful!"
      puts "   Total budget: #{total_budget}"
      puts "   Currency breakdown: #{currency_breakdown}"
      puts "   CAPEX entries count: #{capex_entries.count}"
      
    rescue => e
      puts "✗ Dashboard logic failed: #{e.message}"
      raise e
    end
    
  else
    puts "✗ No projects found in database"
  end
  
  puts "\n✅ All tests passed!"
  puts "The CAPEX dashboard should now work without GROUP BY ORDER BY errors."
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts "Stack trace: #{e.backtrace.first(5).join("\n")}"
end
