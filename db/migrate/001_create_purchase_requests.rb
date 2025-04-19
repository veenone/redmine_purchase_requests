class CreatePurchaseRequests < ActiveRecord::Migration[6.0]
  def change
    # Drop tables if they exist
    drop_table :purchase_requests if table_exists?(:purchase_requests)
    drop_table :purchase_request_statuses if table_exists?(:purchase_request_statuses)
    
    # First create the statuses table
    create_table :purchase_request_statuses do |t|
      t.string :name, null: false
      t.integer :position, default: 1
      t.boolean :is_default, default: false
      t.timestamps
    end
    
    # Add an index for the name to ensure uniqueness
    add_index :purchase_request_statuses, :name, unique: true
    
    # Then create the purchase_requests table with the foreign key
    create_table :purchase_requests do |t|
      t.string :title, null: false
      t.text :description
      t.references :status, null: false, foreign_key: { to_table: :purchase_request_statuses }
      t.references :user, null: false, foreign_key: true
      t.string :product_url
      t.decimal :estimated_price, precision: 10, scale: 2
      t.string :vendor
      t.string :priority, default: 'normal'
      t.date :due_date
      t.boolean :notify_manager, default: false
      t.text :notes
      
      t.timestamps
    end
  end
end