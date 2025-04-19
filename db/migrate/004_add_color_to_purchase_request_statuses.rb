class AddColorToPurchaseRequestStatuses < ActiveRecord::Migration[6.0]
  def change
    # Only add color column if it doesn't exist
    unless column_exists?(:purchase_request_statuses, :color)
      add_column :purchase_request_statuses, :color, :string, default: '#777777', null: false
    end
  end
end