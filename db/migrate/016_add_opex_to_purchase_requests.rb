class AddOpexToPurchaseRequests < ActiveRecord::Migration[6.0]
  def up
    unless column_exists?(:purchase_requests, :opex_id)
      add_column :purchase_requests, :opex_id, :integer, null: true
    end
    
    unless index_exists?(:purchase_requests, :opex_id)
      add_index :purchase_requests, :opex_id
    end
  end
  
  def down
    if index_exists?(:purchase_requests, :opex_id)
      remove_index :purchase_requests, :opex_id
    end
    
    if column_exists?(:purchase_requests, :opex_id)
      remove_column :purchase_requests, :opex_id
    end
  end
end
