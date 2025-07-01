class AddIsClosedToPurchaseRequestStatuses < ActiveRecord::Migration[6.0]
  def up
    unless column_exists?(:purchase_request_statuses, :is_closed)
      add_column :purchase_request_statuses, :is_closed, :boolean, default: false, null: false
    end
  end
  
  def down
    if column_exists?(:purchase_request_statuses, :is_closed)
      remove_column :purchase_request_statuses, :is_closed
    end
  end
end
