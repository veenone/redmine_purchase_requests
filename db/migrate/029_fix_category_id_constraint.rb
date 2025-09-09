class FixCategoryIdConstraint < ActiveRecord::Migration[5.2]
  def up
    # Make category_id nullable
    change_column_null :purchase_requests, :category_id, true
    
    # Set default value to NULL for existing records if needed
    execute "UPDATE purchase_requests SET category_id = NULL WHERE category_id = 0" if connection.adapter_name.downcase.include?('mysql')
  end
  
  def down
    # This is irreversible as we cannot make it NOT NULL again without data loss
    # But we include it for completeness
    # You would need to ensure all records have a category_id before running this
    # change_column_null :purchase_requests, :category_id, false
  end
end