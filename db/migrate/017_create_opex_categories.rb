class CreateOpexCategories < ActiveRecord::Migration[6.0]
  def change
    create_table :opex_categories, id: :bigint do |t|
      t.string :name, null: false
      t.integer :position, default: 1
      t.timestamps
    end
    add_index :opex_categories, :name, unique: true
  end
end
