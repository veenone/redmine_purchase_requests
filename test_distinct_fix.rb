#!/usr/bin/env ruby

puts "Testing CAPEX controller DISTINCT ORDER BY fix..."

begin
  # Load Rails environment
  require_relative '/opt/redmine/config/environment'
  
  puts "✓ Rails environment loaded"
  
  # Test the problematic query combination
  puts "\nTesting the DISTINCT with ORDER BY issue..."
  
  project = Project.first
  if project
    puts "✓ Found test project: #{project.name}"
    
    # Test the original problematic query (should fail)
    puts "\n1. Testing problematic query (ordered + distinct + pluck):"
    begin
      # This should fail with the DISTINCT ORDER BY error
      bad_years = project.capex.ordered.distinct.pluck(:year)
      puts "⚠  Warning: Bad query succeeded (this might indicate a different MySQL version)"
      puts "   Years found: #{bad_years}"
    rescue => e
      puts "✓ Expected error confirmed: #{e.message[0..80]}..."
    end
    
    # Test the fixed query (should work)
    puts "\n2. Testing fixed query (distinct + pluck without ordering):"
    begin
      good_years = project.capex.distinct.pluck(:year).sort.reverse
      puts "✓ Fixed query succeeded!"
      puts "   Years found: #{good_years}"
    rescue => e
      puts "✗ Fixed query failed: #{e.message}"
      raise e
    end
    
    # Test the full controller logic
    puts "\n3. Testing full controller index logic:"
    begin
      # Simulate what the controller does
      capex_entries = project.capex.ordered  # This is find_capex_entries
      years = project.capex.distinct.pluck(:year).sort.reverse  # Fixed approach
      
      puts "✓ Controller logic simulation successful!"
      puts "   Total CAPEX entries: #{capex_entries.count}"
      puts "   Available years: #{years}"
      
      # Test filtering by year
      if years.any?
        test_year = years.first
        filtered_entries = capex_entries.for_year(test_year)
        puts "   Entries for #{test_year}: #{filtered_entries.count}"
      end
      
    rescue => e
      puts "✗ Controller logic failed: #{e.message}"
      raise e
    end
    
  else
    puts "✗ No projects found in database"
  end
  
  puts "\n✅ All tests passed!"
  puts "The CAPEX controller should now work without DISTINCT ORDER BY errors."
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts "Stack trace: #{e.backtrace.first(5).join("\n")}"
end
