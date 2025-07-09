class AddQuarterlyDistributionToPurchaseRequests < ActiveRecord::Migration[5.2]
  def up
    unless column_exists?(:purchase_requests, :q1_amount)
      add_column :purchase_requests, :q1_amount, :decimal, precision: 15, scale: 2, default: 0
    end
    
    unless column_exists?(:purchase_requests, :q2_amount)
      add_column :purchase_requests, :q2_amount, :decimal, precision: 15, scale: 2, default: 0
    end
    
    unless column_exists?(:purchase_requests, :q3_amount)
      add_column :purchase_requests, :q3_amount, :decimal, precision: 15, scale: 2, default: 0
    end
    
    unless column_exists?(:purchase_requests, :q4_amount)
      add_column :purchase_requests, :q4_amount, :decimal, precision: 15, scale: 2, default: 0
    end
    
    unless column_exists?(:purchase_requests, :total_amount)
      add_column :purchase_requests, :total_amount, :decimal, precision: 15, scale: 2, default: 0
    end
  end

  def down
    if column_exists?(:purchase_requests, :q1_amount)
      remove_column :purchase_requests, :q1_amount
    end
    
    if column_exists?(:purchase_requests, :q2_amount)
      remove_column :purchase_requests, :q2_amount
    end
    
    if column_exists?(:purchase_requests, :q3_amount)
      remove_column :purchase_requests, :q3_amount
    end
    
    if column_exists?(:purchase_requests, :q4_amount)
      remove_column :purchase_requests, :q4_amount
    end
    
    if column_exists?(:purchase_requests, :total_amount)
      remove_column :purchase_requests, :total_amount
    end
  end
end
