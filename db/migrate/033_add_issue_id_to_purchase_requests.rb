class AddIssueIdToPurchaseRequests < ActiveRecord::Migration[5.2]
  def change
    # Add issue_id to link purchase requests with Redmine issues
    unless column_exists?(:purchase_requests, :issue_id)
      add_column :purchase_requests, :issue_id, :integer
      add_index :purchase_requests, :issue_id
    end

    # Add foreign key if not exists
    unless foreign_key_exists?(:purchase_requests, :issues)
      add_foreign_key :purchase_requests, :issues, on_delete: :nullify
    end
  end
end
