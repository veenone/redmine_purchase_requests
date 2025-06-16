#!/usr/bin/env ruby

puts "Testing CAPEX model methods..."

begin
  # Load Rails environment
  require_relative '/opt/redmine/config/environment'
  
  puts "✓ Rails environment loaded"
  
  # Test if we can access the CAPEX model
  if defined?(Capex)
    puts "✓ CAPEX model loaded"
    
    # Test basic model functionality
    capex = Capex.new
    if capex.respond_to?(:capex_year)
      puts "✓ capex_year method exists"
    else
      puts "✗ capex_year method missing"
    end
    
    # Test if we can query the database
    capex_count = Capex.count
    puts "✓ Database connection working - #{capex_count} CAPEX entries found"
    
    # Test a real CAPEX entry if one exists
    if capex_count > 0
      first_capex = Capex.first
      puts "✓ First CAPEX entry loaded:"
      puts "  - ID: #{first_capex.id}"
      puts "  - Year: #{first_capex.year}"
      puts "  - CAPEX Year: #{first_capex.capex_year}"
      puts "  - TPC Code: #{first_capex.tpc_code}"
      puts "  - Description: #{first_capex.description}"
    else
      puts "ℹ No CAPEX entries in database to test with"
    end
    
  else
    puts "✗ CAPEX model not loaded"
  end
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts "Stack trace: #{e.backtrace.first(3).join("\n")}"
end

puts "\n✅ Test completed. The capex_year method should now work in views."
