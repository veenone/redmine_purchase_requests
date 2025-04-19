class CreatePurchaseRequestStatuses < ActiveRecord::Migration[6.0]
  def change
    # Add description column to the existing purchase_request_statuses table
    add_column :purchase_request_statuses, :description, :text unless column_exists?(:purchase_request_statuses, :description)
  end
end