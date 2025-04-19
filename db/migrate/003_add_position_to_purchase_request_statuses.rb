class AddPositionToPurchaseRequestStatuses < ActiveRecord::Migration[6.0]
  def change
    # Only add position column if it doesn't exist
    unless column_exists?(:purchase_request_statuses, :position)
      add_column :purchase_request_statuses, :position, :integer, default: 1, null: false
    end
    
    # Only add is_closed column if it doesn't exist
    unless column_exists?(:purchase_request_statuses, :is_closed)
      add_column :purchase_request_statuses, :is_closed, :boolean, default: false, null: false
    end
  end
end