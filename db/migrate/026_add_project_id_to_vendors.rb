class AddProjectIdToVendors < ActiveRecord::Migration[5.2]
  def change
    add_column :vendors, :project_id, :integer
    add_index :vendors, :project_id
    
    # Allow project-specific vendors to have same name as global vendors
    # Remove the unique constraint on name and add a composite unique constraint
    remove_index :vendors, :name if index_exists?(:vendors, :name)
    add_index :vendors, [:name, :project_id], unique: true
  end
end
