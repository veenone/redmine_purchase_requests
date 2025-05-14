class CreateVendors < ActiveRecord::Migration[5.2]
  def change
    create_table :vendors do |t|
      t.string :name, null: false, index: { unique: true }
      t.string :vendor_id
      t.string :address
      t.string :phone
      t.string :contact_person
      t.string :email
      
      t.timestamps
    end
    
    # Add vendor_id to purchase_requests as foreign key
    add_column :purchase_requests, :vendor_id, :integer
    add_index :purchase_requests, :vendor_id
  end
end
