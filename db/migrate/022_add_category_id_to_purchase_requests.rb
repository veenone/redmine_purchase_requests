class AddCategoryIdToPurchaseRequests < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:purchase_requests, :category_id)
      add_column :purchase_requests, :category_id, :bigint, null: true
      add_index :purchase_requests, :category_id
    end
  end
end
