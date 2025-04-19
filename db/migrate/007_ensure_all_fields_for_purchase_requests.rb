class EnsureAllFieldsForPurchaseRequests < ActiveRecord::Migration[6.0]
  def change
    # Check and add each field if it doesn't exist
    unless column_exists?(:purchase_requests, :product_url)
      add_column :purchase_requests, :product_url, :string
    end
    
    unless column_exists?(:purchase_requests, :estimated_price)
      add_column :purchase_requests, :estimated_price, :decimal, precision: 10, scale: 2
    end
    
    unless column_exists?(:purchase_requests, :vendor)
      add_column :purchase_requests, :vendor, :string
    end
    
    unless column_exists?(:purchase_requests, :priority)
      add_column :purchase_requests, :priority, :string, default: 'normal'
    end
    
    unless column_exists?(:purchase_requests, :due_date)
      add_column :purchase_requests, :due_date, :date
    end
    
    unless column_exists?(:purchase_requests, :notify_manager)
      add_column :purchase_requests, :notify_manager, :boolean, default: false
    end
    
    unless column_exists?(:purchase_requests, :notes)
      add_column :purchase_requests, :notes, :text
    end
  end
end