class AddMissingFieldsToVendors < ActiveRecord::Migration[5.2]
  def change
    add_column :vendors, :website, :string
    add_column :vendors, :notes, :text
    add_column :vendors, :is_active, :boolean, default: true
  end
end
