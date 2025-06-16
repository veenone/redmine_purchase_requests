#!/usr/bin/env ruby

puts "Creating CAPEX table manually..."

begin
  # Load Rails environment
  require_relative '/opt/redmine/config/environment'
  
  puts "✓ Rails environment loaded"
  
  # Create the table manually using ActiveRecord
  ActiveRecord::Schema.define do
    # Drop existing tables if they exist
    drop_table :capex if table_exists?(:capex)
    drop_table :capexes if table_exists?(:capexes)
    
    # Create capex table
    create_table :capex, force: true do |t|
      t.integer :project_id, null: false
      t.integer :year, null: false
      t.string :description, null: false
      t.string :tpc_code, null: false
      t.decimal :total_amount, precision: 15, scale: 2, null: false
      t.string :currency, null: false, default: 'USD'
      t.decimal :q1_amount, precision: 15, scale: 2, null: false, default: 0.0
      t.decimal :q2_amount, precision: 15, scale: 2, null: false, default: 0.0
      t.decimal :q3_amount, precision: 15, scale: 2, null: false, default: 0.0
      t.decimal :q4_amount, precision: 15, scale: 2, null: false, default: 0.0
      t.text :notes
      t.timestamps null: false
    end
    
    # Add indices
    add_index :capex, :project_id
    add_index :capex, [:project_id, :year]
    add_index :capex, [:project_id, :tpc_code]
    add_index :capex, :year
  end
  
  puts "✓ CAPEX table created successfully"
  
  # Add capex_id to purchase_requests if it doesn't exist
  unless ActiveRecord::Base.connection.column_exists?(:purchase_requests, :capex_id)
    ActiveRecord::Base.connection.add_column :purchase_requests, :capex_id, :integer
    ActiveRecord::Base.connection.add_index :purchase_requests, :capex_id
    puts "✓ Added capex_id to purchase_requests table"
  else
    puts "✓ capex_id already exists in purchase_requests table"
  end
  
  # Verify table was created
  if ActiveRecord::Base.connection.table_exists?('capex')
    columns = ActiveRecord::Base.connection.columns('capex')
    puts "✓ Verification: CAPEX table exists with #{columns.length} columns"
    columns.each do |col|
      puts "  - #{col.name} (#{col.type})"
    end
  else
    puts "✗ Failed to create CAPEX table"
  end
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
