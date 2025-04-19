class AddProductUrlToPurchaseRequests < ActiveRecord::Migration[6.0]
  def change
    # Check if the column exists before adding it
    unless column_exists?(:purchase_requests, :product_url)
      add_column :purchase_requests, :product_url, :string
    end
  end
end