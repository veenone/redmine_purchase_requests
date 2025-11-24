class CreatePurchaseRequestSubtasks < ActiveRecord::Migration[5.2]
  def change
    create_table :purchase_request_subtasks do |t|
      t.references :purchase_request, null: false, foreign_key: true
      t.references :issue, null: false, foreign_key: { on_delete: :cascade }
      t.references :workflow_template, foreign_key: { to_table: :purchase_request_workflow_templates, on_delete: :nullify }
      t.string :subtask_type
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :purchase_request_subtasks, [:purchase_request_id, :subtask_type], name: 'idx_pr_subtasks_pr_type'
    add_index :purchase_request_subtasks, :position
  end
end
