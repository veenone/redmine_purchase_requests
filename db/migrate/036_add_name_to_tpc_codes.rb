class AddNameToTpcCodes < ActiveRecord::Migration[5.2]
  def change
    add_column :tpc_codes, :tpc_name, :string, limit: 150, null: true
    add_index :tpc_codes, :tpc_name
  end
end
