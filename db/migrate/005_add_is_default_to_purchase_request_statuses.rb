class AddIsDefaultToPurchaseRequestStatuses < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:purchase_request_statuses, :is_default)
      add_column :purchase_request_statuses, :is_default, :boolean, default: false, null: false
    end
    
    # Set the first status as default if no default exists
    if PurchaseRequestStatus.count > 0 && PurchaseRequestStatus.where(is_default: true).count == 0
      first_status = PurchaseRequestStatus.order(:position).first
      first_status.update_column(:is_default, true) if first_status
    end
  end
end