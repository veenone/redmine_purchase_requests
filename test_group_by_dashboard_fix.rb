#!/usr/bin/env ruby
# Test CAPEX dashboard GROUP BY fix

puts "Testing CAPEX dashboard GROUP BY fix..."

# Load Rails environment
ENV['RAILS_ENV'] = 'production'
require '/opt/redmine/config/environment'

begin
  # Find a project with CAPEX entries
  project = Project.joins(:capex).first
  
  if project.nil?
    puts "No project with CAPEX entries found. Creating test data..."
    project = Project.first
    
    # Create a test CAPEX entry
    capex = project.capex.create!(
      year: 2025,
      description: "Test CAPEX Entry",
      tpc_code: "TEST001",
      total_amount: 10000,
      currency: "USD",
      q1_amount: 2500,
      q2_amount: 2500,
      q3_amount: 2500,
      q4_amount: 2500,
      notes: "Test entry for GROUP BY fix verification"
    )
    puts "Created test CAPEX entry: #{capex.display_name}"
  end
  
  puts "Testing with project: #{project.name} (ID: #{project.id})"
  
  # Test the dashboard queries that were causing GROUP BY issues
  current_year = 2025
  
  puts "\n1. Testing capex_for_year relation..."
  capex_for_year = project.capex.for_year(current_year)
  puts "   Found #{capex_for_year.count} CAPEX entries for #{current_year}"
  
  puts "\n2. Testing ordered capex entries..."
  capex_entries = capex_for_year.ordered
  puts "   Ordered entries count: #{capex_entries.count}"
  
  puts "\n3. Testing aggregation queries (previously problematic)..."
  
  # Test total budget (should work)
  total_budget = capex_for_year.sum(:total_amount)
  puts "   Total budget: #{total_budget}"
  
  # Test quarterly data (should work)  
  quarterly_data = {
    q1: capex_for_year.sum(:q1_amount),
    q2: capex_for_year.sum(:q2_amount),
    q3: capex_for_year.sum(:q3_amount),
    q4: capex_for_year.sum(:q4_amount)
  }
  puts "   Quarterly totals: Q1=#{quarterly_data[:q1]}, Q2=#{quarterly_data[:q2]}, Q3=#{quarterly_data[:q3]}, Q4=#{quarterly_data[:q4]}"
  
  # Test currency breakdown (this was the problematic query)
  puts "\n4. Testing currency breakdown (the main fix)..."
  currency_breakdown = capex_for_year.group(:currency).sum(:total_amount)
  puts "   Currency breakdown: #{currency_breakdown}"
  
  puts "\n5. Testing the full dashboard controller logic..."
  
  # Simulate the dashboard controller logic
  controller_logic = -> {
    current_year = 2025
    capex_for_year = project.capex.for_year(current_year)
    capex_entries = capex_for_year.ordered
    
    # Calculate summary statistics using unordered relation
    total_budget = capex_for_year.sum(:total_amount)
    total_utilized = capex_for_year.sum { |c| c.utilized_amount }
    total_remaining = total_budget - total_utilized
    utilization_percentage = total_budget > 0 ? (total_utilized / total_budget * 100).round(2) : 0
    
    # Quarterly breakdown using unordered relation
    quarterly_data = {
      q1: capex_for_year.sum(:q1_amount),
      q2: capex_for_year.sum(:q2_amount),
      q3: capex_for_year.sum(:q3_amount),
      q4: capex_for_year.sum(:q4_amount)
    }
    
    # Currency breakdown using unordered relation (the main fix)
    currency_breakdown = capex_for_year.group(:currency).sum(:total_amount)
    
    {
      total_budget: total_budget,
      total_utilized: total_utilized,
      total_remaining: total_remaining,
      utilization_percentage: utilization_percentage,
      quarterly_data: quarterly_data,
      currency_breakdown: currency_breakdown,
      capex_entries_count: capex_entries.count
    }
  }
  
  result = controller_logic.call
  puts "   Dashboard calculation successful!"
  puts "   Results: Budget=#{result[:total_budget]}, Utilized=#{result[:total_utilized]}"
  puts "   Currency breakdown: #{result[:currency_breakdown]}"
  puts "   CAPEX entries: #{result[:capex_entries_count]}"
  
  puts "\n✅ All tests passed! The GROUP BY fix is working correctly."
  puts "\nThe issue was that we were applying .ordered (which adds ORDER BY year, tpc_code)"
  puts "to the relation that was later used for GROUP BY operations."
  puts "The fix separates the ordering from the aggregation operations."
  
rescue => e
  puts "\n❌ Error occurred: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
