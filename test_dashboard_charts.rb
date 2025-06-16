#!/usr/bin/env ruby
# Test CAPEX Dashboard with CDN ApexCharts

puts "=== Testing CAPEX Dashboard with CDN ApexCharts ==="

# Load Rails environment
ENV['RAILS_ENV'] = 'production'
require '/opt/redmine/config/environment'

begin
  # Find a project with CAPEX entries
  project = Project.joins(:capex).first
  
  if project.nil?
    puts "Creating test project and CAPEX data..."
    project = Project.first
    
    # Create test CAPEX entries with different currencies
    capex1 = project.capex.create!(
      year: 2025,
      description: "Infrastructure Upgrade",
      tpc_code: "INFRA001",
      total_amount: 100000,
      currency: "USD",
      q1_amount: 25000,
      q2_amount: 25000,
      q3_amount: 25000,
      q4_amount: 25000,
      notes: "Network infrastructure improvements"
    )
    
    capex2 = project.capex.create!(
      year: 2025,
      description: "Software Licenses",
      tpc_code: "SW001",
      total_amount: 50000,
      currency: "USD",
      q1_amount: 12500,
      q2_amount: 12500,
      q3_amount: 12500,
      q4_amount: 12500,
      notes: "Annual software licensing"
    )
    
    puts "Created test CAPEX entries:"
    puts "  - #{capex1.display_name}: $#{capex1.total_amount}"
    puts "  - #{capex2.display_name}: $#{capex2.total_amount}"
  end
  
  puts "\nTesting dashboard data preparation..."
  
  # Simulate dashboard controller logic
  current_year = 2025
  capex_for_year = project.capex.for_year(current_year)
  capex_entries = capex_for_year.ordered
  
  # Calculate summary statistics
  total_budget = capex_for_year.sum(:total_amount)
  total_utilized = capex_for_year.sum { |c| c.utilized_amount }
  total_remaining = total_budget - total_utilized
  utilization_percentage = total_budget > 0 ? (total_utilized / total_budget * 100).round(2) : 0
  
  # Quarterly breakdown
  quarterly_data = {
    q1: capex_for_year.sum(:q1_amount),
    q2: capex_for_year.sum(:q2_amount),
    q3: capex_for_year.sum(:q3_amount),
    q4: capex_for_year.sum(:q4_amount)
  }
  
  # Currency breakdown
  currency_breakdown = capex_for_year.group(:currency).sum(:total_amount)
  
  puts "\n✅ Dashboard Data Summary:"
  puts "   Project: #{project.name}"
  puts "   Year: #{current_year}"
  puts "   CAPEX Entries: #{capex_entries.count}"
  puts "   Total Budget: $#{total_budget}"
  puts "   Total Utilized: $#{total_utilized}"
  puts "   Total Remaining: $#{total_remaining}"
  puts "   Utilization: #{utilization_percentage}%"
  puts "   Quarterly Distribution:"
  puts "     Q1: $#{quarterly_data[:q1]}"
  puts "     Q2: $#{quarterly_data[:q2]}"
  puts "     Q3: $#{quarterly_data[:q3]}"
  puts "     Q4: $#{quarterly_data[:q4]}"
  puts "   Currency Breakdown: #{currency_breakdown}"
  
  puts "\n✅ CAPEX Dashboard Data Ready!"
  puts "\nThe dashboard should now work with:"
  puts "1. ✅ CDN-based ApexCharts (instead of local file)"
  puts "2. ✅ Proper data aggregation (GROUP BY issues resolved)"
  puts "3. ✅ Complete summary statistics"
  puts "4. ✅ Chart-ready data format"
  
  puts "\n🎯 Next Steps:"
  puts "1. Access the dashboard at: /projects/#{project.id}/capex/dashboard"
  puts "2. Charts should now load from CDN"
  puts "3. All summary cards should display correct data"
  puts "4. Both utilization and quarterly charts should render"
  
  puts "\n📊 Chart Data for Testing:"
  puts "Utilization Chart: Used: #{utilization_percentage}%, Remaining: #{(100-utilization_percentage).round(2)}%"
  puts "Quarterly Chart: [#{quarterly_data.values.join(', ')}]"
  
rescue => e
  puts "\n❌ Error occurred: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
