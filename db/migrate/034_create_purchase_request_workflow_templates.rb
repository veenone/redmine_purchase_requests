class CreatePurchaseRequestWorkflowTemplates < ActiveRecord::Migration[5.2]
  def change
    create_table :purchase_request_workflow_templates do |t|
      t.string :name, null: false
      t.text :description
      t.integer :position, default: 0
      t.boolean :is_active, default: true
      t.boolean :auto_create, default: false
      t.integer :tracker_id
      t.integer :default_assigned_to_id
      t.integer :estimated_hours
      t.timestamps
    end

    add_index :purchase_request_workflow_templates, :position
    add_index :purchase_request_workflow_templates, :is_active
  end
end
