require 'securerandom'

class AllowNullOpexCode < ActiveRecord::Migration[5.2]
  def up
    # Check if opex_code column exists and has NOT NULL constraint
    if column_exists?(:opex, :opex_code)
      # Change column to allow NULL values
      change_column_null :opex, :opex_code, true
      
      # Update any existing records that might have empty opex_code
      # Use a simpler approach that works with MySQL
      Opex.where(opex_code: [nil, '']).find_each do |opex|
        if opex.tpc_code_id.present?
          tpc = TpcCode.find_by(id: opex.tpc_code_id)
          opex.update_column(:opex_code, tpc&.tpc_number || "TPC-#{opex.tpc_code_id}")
        else
          opex.update_column(:opex_code, "OPEX-#{opex.year}-#{SecureRandom.hex(4).upcase}")
        end
      end
    end
  end
  
  def down
    # Restore NOT NULL constraint
    # First ensure all records have a value
    Opex.where(opex_code: [nil, '']).find_each do |opex|
      if opex.tpc_code_id.present?
        tpc = TpcCode.find_by(id: opex.tpc_code_id)
        opex.update_column(:opex_code, tpc&.tpc_number || "TPC-#{opex.tpc_code_id}")
      else
        opex.update_column(:opex_code, "OPEX-#{opex.year}-#{SecureRandom.hex(4).upcase}")
      end
    end
    
    change_column_null :opex, :opex_code, false
  end
end
