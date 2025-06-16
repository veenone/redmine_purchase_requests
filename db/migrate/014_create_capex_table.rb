class CreateCapexTable < ActiveRecord::Migration[5.2]
  def up
    # Drop table if it exists (in case of partial creation)
    drop_table :capex if table_exists?(:capex)
    drop_table :capexes if table_exists?(:capexes)
    
    # Create the capex table with singular name
    create_table :capex, force: true do |t|
      t.integer :project_id, null: false
      t.integer :year, null: false
      t.string :description, null: false, limit: 255
      t.string :tpc_code, null: false, limit: 50
      t.decimal :total_amount, precision: 15, scale: 2, null: false
      t.string :currency, null: false, limit: 3, default: 'USD'
      t.decimal :q1_amount, precision: 15, scale: 2, null: false, default: 0.0
      t.decimal :q2_amount, precision: 15, scale: 2, null: false, default: 0.0
      t.decimal :q3_amount, precision: 15, scale: 2, null: false, default: 0.0
      t.decimal :q4_amount, precision: 15, scale: 2, null: false, default: 0.0
      t.text :notes
      t.timestamps null: false
    end
    
    # Add indices for performance
    add_index :capex, :project_id
    add_index :capex, [:project_id, :year]
    add_index :capex, [:project_id, :tpc_code]
    add_index :capex, :year
    
    # Add foreign key constraint
    add_foreign_key :capex, :projects, column: :project_id if foreign_key_exists?(:projects, column: :id)
  end
  
  def down
    drop_table :capex if table_exists?(:capex)
  end
end
