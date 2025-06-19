# Redmine Purchase Requests Plugin Migration
# This migration adds CAPEX association support to purchase requests
class RedminePurchaseRequestsAddCapexToPurchaseRequests < ActiveRecord::Migration[5.2]
  def up
    # Add CAPEX ID column to purchase_requests table for linking to CAPEX records
    unless column_exists?(:purchase_requests, :capex_id)
      add_column :purchase_requests, :capex_id, :integer, null: true, comment: 'Foreign key to CAPEX records'
    end
    
    # Add index for CAPEX ID column to improve query performance
    unless index_exists?(:purchase_requests, :capex_id)
      add_index :purchase_requests, :capex_id, name: 'index_purchase_requests_on_capex_id'
    end
  end
  
  def down
    # Remove CAPEX ID index if it exists
    if index_exists?(:purchase_requests, :capex_id)
      remove_index :purchase_requests, :capex_id
    end
    
    # Remove CAPEX ID column if it exists
    if column_exists?(:purchase_requests, :capex_id)
      remove_column :purchase_requests, :capex_id
    end
  end
end
