class AddCategoryIdToOpex < ActiveRecord::Migration[6.0]
  def up
    add_column :opex, :category_id, :bigint
    add_index :opex, :category_id
    add_foreign_key :opex, :opex_categories, column: :category_id
    
    # Remove the old category column if it exists
    remove_column :opex, :category if column_exists?(:opex, :category)
  end

  def down
    remove_foreign_key :opex, :opex_categories
    remove_index :opex, :category_id
    remove_column :opex, :category_id
    add_column :opex, :category, :string
  end
end
