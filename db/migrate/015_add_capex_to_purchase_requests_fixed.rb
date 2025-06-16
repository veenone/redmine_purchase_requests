class AddCapexToPurchaseRequestsFixed < ActiveRecord::Migration[5.2]
  def up
    # Check if column already exists
    unless column_exists?(:purchase_requests, :capex_id)
      add_column :purchase_requests, :capex_id, :integer, null: true
      
      # Add index for performance
      add_index :purchase_requests, :capex_id
      
      # Add foreign key constraint if capex table exists
      if table_exists?(:capex)
        add_foreign_key :purchase_requests, :capex, column: :capex_id
      end
    end
  end
  
  def down
    if column_exists?(:purchase_requests, :capex_id)
      remove_foreign_key :purchase_requests, :capex if foreign_key_exists?(:purchase_requests, :capex)
      remove_column :purchase_requests, :capex_id
    end
  end
end
