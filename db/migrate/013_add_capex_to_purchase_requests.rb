class AddCapexToPurchaseRequests < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:purchase_requests, :capex_id)
      add_column :purchase_requests, :capex_id, :integer, null: true
    end
    
    unless index_exists?(:purchase_requests, :capex_id)
      add_index :purchase_requests, :capex_id
    end
  end
end
