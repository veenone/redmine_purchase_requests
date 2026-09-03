class CreateDepartments < ActiveRecord::Migration[5.2]
  def change
    create_table :departments do |t|
      # code stays nullable: the 039 backfill has only department names to
      # work from and cannot invent codes. An admin fills them in later.
      t.string :code, limit: 20
      t.string :name, limit: 100, null: false
      t.timestamps
    end

    add_index :departments, :name, unique: true
    add_index :departments, :code, unique: true
  end
end
