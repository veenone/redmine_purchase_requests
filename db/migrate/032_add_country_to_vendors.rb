class AddCountryToVendors < ActiveRecord::Migration[5.2]
  def change
    add_column :vendors, :country, :string unless column_exists?(:vendors, :country)
  end
end
