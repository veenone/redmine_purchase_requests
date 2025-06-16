#!/usr/bin/env ruby

# Direct database connection script to create CAPEX table

puts "Attempting to create CAPEX table via Rails database connection..."

begin
  # Load Rails environment
  require_relative '/opt/redmine/config/environment'
  
  # Get database connection
  connection = ActiveRecord::Base.connection
  
  puts "✓ Database connection established"
  puts "Database: #{connection.current_database}"
  
  # Check if table exists
  if connection.table_exists?('capex')
    puts "! CAPEX table already exists, dropping it first..."
    connection.drop_table('capex')
  end
  
  # Create the CAPEX table using raw SQL
  sql = <<-SQL
    CREATE TABLE capex (
      id int(11) NOT NULL AUTO_INCREMENT,
      project_id int(11) NOT NULL,
      year int(11) NOT NULL,
      description varchar(255) NOT NULL,
      tpc_code varchar(50) NOT NULL,
      total_amount decimal(15,2) NOT NULL,
      currency varchar(3) NOT NULL DEFAULT 'USD',
      q1_amount decimal(15,2) NOT NULL DEFAULT 0.00,
      q2_amount decimal(15,2) NOT NULL DEFAULT 0.00,
      q3_amount decimal(15,2) NOT NULL DEFAULT 0.00,
      q4_amount decimal(15,2) NOT NULL DEFAULT 0.00,
      notes text,
      created_at datetime NOT NULL,
      updated_at datetime NOT NULL,
      PRIMARY KEY (id),
      KEY index_capex_on_project_id (project_id),
      KEY index_capex_on_year (year)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  SQL
  
  connection.execute(sql)
  
  puts "✓ CAPEX table created successfully"
  
  # Add capex_id to purchase_requests if it doesn't exist
  unless connection.column_exists?(:purchase_requests, :capex_id)
    connection.add_column :purchase_requests, :capex_id, :integer
    connection.add_index :purchase_requests, :capex_id
    puts "✓ Added capex_id column to purchase_requests"
  else
    puts "✓ capex_id column already exists in purchase_requests"
  end
  
  # Verify table creation
  if connection.table_exists?('capex')
    columns = connection.columns('capex')
    puts "✓ Verification successful - CAPEX table has #{columns.length} columns:"
    columns.each do |col|
      puts "  - #{col.name} (#{col.type})"
    end
  else
    puts "✗ Table creation failed"
  end
  
  puts "\n✅ CAPEX database setup completed successfully!"
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts "Stack trace:"
  puts e.backtrace.first(10).join("\n")
end
