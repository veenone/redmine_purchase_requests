class CreateCapex < ActiveRecord::Migration[5.2]
  def up
    # Drop table if it exists to avoid conflicts
    drop_table :capex if table_exists?(:capex)
    
    create_table :capex, force: true do |t|
      t.integer :project_id, null: false
      t.integer :year, null: false
      t.string :description, null: false
      t.string :tpc_code, null: false
      t.decimal :total_amount, precision: 15, scale: 2, null: false
      t.string :currency, null: false, default: 'USD'
      t.decimal :q1_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :q2_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :q3_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :q4_amount, precision: 15, scale: 2, null: false, default: 0
      t.text :notes
      t.timestamps null: false
    end
    
    add_index :capex, [:project_id, :year]
    add_index :capex, [:project_id, :tpc_code]
    add_index :capex, [:year]
    add_index :capex, :project_id
  end
  
  def down
    drop_table :capex if table_exists?(:capex)
  end
end
