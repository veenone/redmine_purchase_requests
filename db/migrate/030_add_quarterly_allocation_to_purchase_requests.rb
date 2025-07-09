class AddQuarterlyAllocationToPurchaseRequests < ActiveRecord::Migration[5.2]
  def up
    unless column_exists?(:purchase_requests, :allocated_quarter)
      add_column :purchase_requests, :allocated_quarter, :integer, null: true
    end
    
    unless column_exists?(:purchase_requests, :allocated_amount)
      add_column :purchase_requests, :allocated_amount, :decimal, precision: 10, scale: 2, null: true
    end
    
    unless index_exists?(:purchase_requests, :allocated_quarter)
      add_index :purchase_requests, :allocated_quarter
    end
  end

  def down
    if index_exists?(:purchase_requests, :allocated_quarter)
      remove_index :purchase_requests, :allocated_quarter
    end
    
    if column_exists?(:purchase_requests, :allocated_quarter)
      remove_column :purchase_requests, :allocated_quarter
    end
    
    if column_exists?(:purchase_requests, :allocated_amount)
      remove_column :purchase_requests, :allocated_amount
    end
  end
end
