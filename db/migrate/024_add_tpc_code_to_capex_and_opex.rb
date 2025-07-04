class AddTpcCodeToCapexAndOpex < ActiveRecord::Migration[5.2]
  def change
    # Add TPC code reference to CAPEX
    add_column :capex, :tpc_code_id, :integer, null: true
    add_index :capex, :tpc_code_id
    
    # Add TPC code reference to OPEX
    add_column :opex, :tpc_code_id, :integer, null: true
    add_index :opex, :tpc_code_id
  end
end
