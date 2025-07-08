class AddQuarterlyAllocationToPurchaseRequests < ActiveRecord::Migration[6.0]
  def up
    add_column :purchase_requests, :allocated_quarter, :integer, null: true
    add_column :purchase_requests, :allocated_amount, :decimal, precision: 10, scale: 2, null: true
    
    add_index :purchase_requests, :allocated_quarter
  end

  def down
    remove_index :purchase_requests, :allocated_quarter
    remove_column :purchase_requests, :allocated_quarter
    remove_column :purchase_requests, :allocated_amount
  end
end
