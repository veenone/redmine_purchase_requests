class AddCurrencyToPurchaseRequests < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:purchase_requests, :currency)
      add_column :purchase_requests, :currency, :string, default: 'USD', limit: 3
    end
  end
end