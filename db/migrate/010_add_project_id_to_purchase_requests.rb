class AddProjectIdToPurchaseRequests < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:purchase_requests, :project_id)
      # First add the column manually with the right type
      add_column :purchase_requests, :project_id, :integer
      
      # Add index separately
      add_index :purchase_requests, :project_id
      
      # If you're using MySQL and want proper foreign key constraints
      if connection.adapter_name.downcase == 'mysql' || connection.adapter_name.downcase == 'mysql2'
        execute "ALTER TABLE purchase_requests ADD CONSTRAINT fk_purchase_requests_projects FOREIGN KEY (project_id) REFERENCES projects(id)"
      end
      
      # Update existing records
      default_project = Project.first
      if default_project && PurchaseRequest.count > 0
        PurchaseRequest.update_all(project_id: default_project.id)
      end
    end
  end
end