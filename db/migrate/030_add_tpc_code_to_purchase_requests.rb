class AddTpcCodeToPurchaseRequests < ActiveRecord::Migration[5.2]
  def change
    # Add TPC code reference to purchase requests
    add_column :purchase_requests, :tpc_code_id, :integer, null: true
    add_index :purchase_requests, :tpc_code_id
  end
end
