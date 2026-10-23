class AddDescriptionToVendors < ActiveRecord::Migration[5.2]
  def change
    add_column :vendors, :description, :text unless column_exists?(:vendors, :description)
  end
end
