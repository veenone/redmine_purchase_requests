class FixOpexCategoryColumn < ActiveRecord::Migration[6.0]
  def up
    # First, ensure category_id column exists
    unless column_exists?(:opex, :category_id)
      add_column :opex, :category_id, :bigint
      add_index :opex, :category_id
    end
    
    # Add foreign key if it doesn't exist
    unless foreign_key_exists?(:opex, :opex_categories)
      add_foreign_key :opex, :opex_categories, column: :category_id
    end
    
    # Remove the old category column and its index if they exist
    if column_exists?(:opex, :category)
      remove_index :opex, :category if index_exists?(:opex, :category)
      remove_column :opex, :category
    end
  end

  def down
    # Reverse the changes
    if foreign_key_exists?(:opex, :opex_categories)
      remove_foreign_key :opex, :opex_categories
    end
    
    if column_exists?(:opex, :category_id)
      remove_index :opex, :category_id if index_exists?(:opex, :category_id)
      remove_column :opex, :category_id
    end
    
    unless column_exists?(:opex, :category)
      add_column :opex, :category, :string, null: false, default: 'general'
      add_index :opex, :category
    end
  end
end
