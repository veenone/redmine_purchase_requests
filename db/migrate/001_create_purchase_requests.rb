class CreatePurchaseRequests < ActiveRecord::Migration[6.0]
  def up
    # Drop tables if they exist
    drop_table :purchase_requests, if_exists: true
    drop_table :purchase_request_statuses, if_exists: true
    
    # First create the statuses table
    create_table :purchase_request_statuses, id: :bigint do |t|
      t.string :name, null: false
      t.integer :position, default: 1
      t.boolean :is_default, default: false
      t.timestamps
    end
    
    # Add an index for the name to ensure uniqueness
    add_index :purchase_request_statuses, :name, unique: true
    
    # Then create the purchase_requests table with the foreign key
    create_table :purchase_requests, id: :bigint do |t|
      t.string :title, null: false
      t.text :description
      t.references :status, null: false, foreign_key: { to_table: :purchase_request_statuses }
      t.bigint :user_id, null: false
      t.string :product_url
      t.decimal :estimated_price, precision: 10, scale: 2
      t.string :vendor
      t.string :priority, default: 'normal'
      t.date :due_date
      t.boolean :notify_manager, default: false
      t.text :notes
      t.bigint :category_id, null: false
      
      t.timestamps
    end
  end
  
  def down
    drop_table :purchase_requests, if_exists: true
    drop_table :purchase_request_statuses, if_exists: true
  end
end
