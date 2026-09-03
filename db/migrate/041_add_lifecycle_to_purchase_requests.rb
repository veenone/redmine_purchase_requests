class AddLifecycleToPurchaseRequests < ActiveRecord::Migration[5.2]
  # Guarded throughout: this plugin's migrations have been re-run against
  # partially-migrated databases before, and a bare add_column would abort.
  def up
    unless column_exists?(:purchase_requests, :lifecycle)
      add_column :purchase_requests, :lifecycle, :string, null: false, default: 'active'
      add_index :purchase_requests, :lifecycle
    end

    unless column_exists?(:purchase_requests, :revision_of_id)
      add_column :purchase_requests, :revision_of_id, :integer, null: true
      # Unique, not merely indexed: it is what makes it impossible to
      # revise one request twice and end up with two children both
      # consuming budget against a single intent. MySQL permits repeated
      # NULLs, so unrevised requests are unaffected.
      add_index :purchase_requests, :revision_of_id, unique: true
    end

    unless column_exists?(:purchase_requests, :revision_number)
      add_column :purchase_requests, :revision_number, :integer, null: false, default: 1
    end

    unless column_exists?(:purchase_requests, :cancelled_at)
      add_column :purchase_requests, :cancelled_at, :datetime, null: true
      add_column :purchase_requests, :cancelled_by_id, :integer, null: true
      add_column :purchase_requests, :cancellation_reason, :text, null: true
      add_index :purchase_requests, :cancelled_by_id
    end
  end

  def down
    %i[lifecycle revision_of_id revision_number
       cancelled_at cancelled_by_id cancellation_reason].each do |col|
      remove_column :purchase_requests, col if column_exists?(:purchase_requests, col)
    end
  end
end
