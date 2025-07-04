class CreateTpcCodes < ActiveRecord::Migration[5.2]
  def change
    create_table :tpc_codes do |t|
      t.string :tpc_number, null: false
      t.string :tpc_owner_name, null: false
      t.string :tpc_email, null: false
      t.text :description
      t.boolean :is_active, default: true
      t.integer :project_id, null: true, index: true
      t.text :notes
      
      t.timestamps
    end
    
    # Add unique index for TPC number within project scope (null project means global)
    add_index :tpc_codes, [:tpc_number, :project_id], unique: true, name: 'index_tpc_codes_on_number_and_project'
    
    # Add index for email for quick lookups
    add_index :tpc_codes, :tpc_email
    
    # Add index for active status
    add_index :tpc_codes, :is_active
  end
end
