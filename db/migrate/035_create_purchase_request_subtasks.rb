class CreatePurchaseRequestSubtasks < ActiveRecord::Migration[5.2]
  def change
    create_table :purchase_request_subtasks do |t|
      t.bigint :purchase_request_id, null: false
      t.integer :issue_id, null: false
      t.bigint :workflow_template_id
      t.string :subtask_type
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :purchase_request_subtasks, :purchase_request_id
    add_index :purchase_request_subtasks, :issue_id
    add_index :purchase_request_subtasks, :workflow_template_id
    add_index :purchase_request_subtasks, [:purchase_request_id, :subtask_type], name: 'idx_pr_subtasks_pr_type'
    add_index :purchase_request_subtasks, :position

    add_foreign_key :purchase_request_subtasks, :purchase_requests
    add_foreign_key :purchase_request_subtasks, :issues, on_delete: :cascade
    add_foreign_key :purchase_request_subtasks, :purchase_request_workflow_templates, column: :workflow_template_id, on_delete: :nullify
  end
end
