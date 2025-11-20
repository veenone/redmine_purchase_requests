class AddDepartmentToTpcCodes < ActiveRecord::Migration[5.2]
  def change
    add_column :tpc_codes, :department, :string, limit: 100, null: true
    add_index :tpc_codes, :department
  end
end
