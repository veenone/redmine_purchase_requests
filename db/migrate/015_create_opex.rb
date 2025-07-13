class CreateOpex < ActiveRecord::Migration[6.0]
  def up
    unless table_exists?(:opex)
      create_table :opex, id: :bigint do |t|
        t.integer :project_id, null: false
        t.integer :year, null: false
        t.string :description, null: false
        t.string :opex_code, null: false
        t.decimal :total_amount, precision: 15, scale: 2, null: false
        t.string :currency, null: false, default: 'USD'
        t.decimal :q1_amount, precision: 15, scale: 2, default: 0
        t.decimal :q2_amount, precision: 15, scale: 2, default: 0
        t.decimal :q3_amount, precision: 15, scale: 2, default: 0
        t.decimal :q4_amount, precision: 15, scale: 2, default: 0
        t.string :category, null: false, default: 'general'
        t.string :cost_center
        t.string :approved_by
        t.datetime :approved_at
        t.string :status, default: 'active'
        t.text :notes
        t.timestamps
      end
    end
    
    # Add foreign key if it doesn't exist
    unless foreign_key_exists?(:opex, :projects)
      add_foreign_key :opex, :projects, column: :project_id
    end

    # Add missing columns if they don't exist (for existing tables)
    unless column_exists?(:opex, :category)
      add_column :opex, :category, :string, null: false, default: 'general'
    end
    
    unless column_exists?(:opex, :status)
      add_column :opex, :status, :string, default: 'active'
    end
    
    # Add indexes if they don't exist
    unless index_exists?(:opex, [:project_id, :year])
      add_index :opex, [:project_id, :year]
    end
    
    if column_exists?(:opex, :opex_code) && !index_exists?(:opex, [:opex_code, :year])
      add_index :opex, [:opex_code, :year], unique: true
    end
    
    if column_exists?(:opex, :category) && !index_exists?(:opex, :category)
      add_index :opex, :category
    end
    
    if column_exists?(:opex, :status) && !index_exists?(:opex, :status)
      add_index :opex, :status
    end
  end
  
  def down
    drop_table :opex, if_exists: true
  end
end
