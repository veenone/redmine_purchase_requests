class IncreaseEstimatedPricePrecision < ActiveRecord::Migration[5.2]
  # precision 10 tops out at 99,999,999.99, which is too small for
  # currencies with large denominations such as IDR. precision 15 matches
  # the max_purchase_amount fallback in PurchaseRequest.
  def up
    change_column :purchase_requests, :estimated_price, :decimal, precision: 15, scale: 2
  end

  def down
    change_column :purchase_requests, :estimated_price, :decimal, precision: 10, scale: 2
  end
end
