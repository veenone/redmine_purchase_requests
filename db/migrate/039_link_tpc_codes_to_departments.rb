class LinkTpcCodesToDepartments < ActiveRecord::Migration[5.2]
  # Additive only: adds department_id and backfills it, and deliberately does
  # NOT drop tpc_codes.department.
  #
  # The running Passenger worker holds the old schema and old code, and keeps
  # naming `department` in its INSERTs and UPDATEs. Dropping the column here
  # would break every TPC code create and edit until the app restarts with the
  # new code. Migration 040 drops it immediately before that restart instead,
  # which shrinks the broken window to the gap between the two.
  #
  # Every step is guarded. MySQL does not roll DDL back, so a run that failed
  # part way through must be able to resume rather than need manual repair.
  def up
    unless column_exists?(:tpc_codes, :department_id)
      add_column :tpc_codes, :department_id, :bigint, null: true
    end
    unless index_exists?(:tpc_codes, :department_id)
      add_index :tpc_codes, :department_id
    end
    unless foreign_key_exists?(:tpc_codes, :departments)
      add_foreign_key :tpc_codes, :departments, on_delete: :nullify
    end

    backfill_departments if column_exists?(:tpc_codes, :department)
  end

  def down
    if foreign_key_exists?(:tpc_codes, :departments)
      remove_foreign_key :tpc_codes, :departments
    end
    if index_exists?(:tpc_codes, :department_id)
      remove_index :tpc_codes, :department_id
    end
    if column_exists?(:tpc_codes, :department_id)
      remove_column :tpc_codes, :department_id
    end
  end

  private

  # Groups by a normalised key so "R&D", "r & d" and "  R&D  " collapse into
  # one department, taking the most common original spelling as canonical.
  #
  # find-or-create rather than a blind INSERT: this runs again in migration 040
  # to catch rows written after 039, and departments created here survive a
  # rollback, so it must tolerate finding one already present.
  def backfill_departments
    rows = select_all(
      "SELECT department, COUNT(*) AS n FROM tpc_codes " \
      "WHERE department IS NOT NULL AND department <> '' AND department_id IS NULL " \
      "GROUP BY department"
    ).to_a

    rows.group_by { |r| r['department'].to_s.strip.downcase }.each_value do |variants|
      canonical = variants.max_by { |r| r['n'].to_i }['department'].to_s.strip
      quoted    = quote(canonical)

      dept_id = select_value("SELECT id FROM departments WHERE LOWER(name) = LOWER(#{quoted})")
      if dept_id.nil?
        execute "INSERT INTO departments (name, created_at, updated_at) VALUES (#{quoted}, NOW(), NOW())"
        dept_id = select_value('SELECT LAST_INSERT_ID()')
      end

      variants.each do |r|
        execute "UPDATE tpc_codes SET department_id = #{dept_id} " \
                "WHERE department = #{quote(r['department'])} AND department_id IS NULL"
      end
    end
  end
end
