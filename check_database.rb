#!/usr/bin/env ruby

puts "Checking CAPEX table in database..."

# Check if we can connect to the database
begin
  # Load Rails environment
  require_relative '/opt/redmine/config/environment'
  
  puts "✓ Rails environment loaded"
  
  # Check if capex table exists
  if ActiveRecord::Base.connection.table_exists?('capex')
    puts "✓ 'capex' table exists"
    
    # Get table info
    columns = ActiveRecord::Base.connection.columns('capex')
    puts "✓ Table has #{columns.length} columns:"
    columns.each do |col|
      puts "  - #{col.name} (#{col.type})"
    end
  else
    puts "✗ 'capex' table does NOT exist"
  end
  
  # Check if capexes table exists (plural)
  if ActiveRecord::Base.connection.table_exists?('capexes')
    puts "✓ 'capexes' table exists"
  else
    puts "✗ 'capexes' table does NOT exist"
  end
  
  # Check plugin migrations
  puts "\nChecking plugin migrations..."
  migration_files = Dir['/opt/redmine/plugins/redmine_purchase_requests/db/migrate/*.rb']
  puts "Found #{migration_files.length} migration files:"
  migration_files.sort.each do |file|
    puts "  - #{File.basename(file)}"
  end
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts "This might indicate a database connection issue or missing migrations"
end
