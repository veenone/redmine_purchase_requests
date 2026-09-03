class DropTpcCodesDepartmentString < ActiveRecord::Migration[5.2]
  # Completes the move to the departments table by dropping the free-text
  # column that migration 039 deliberately left in place.
  #
  # 039 was additive so the running app -- which still held the old schema and
  # kept naming `department` in its INSERTs -- would not break the moment the
  # column vanished. This migration must therefore run IMMEDIATELY BEFORE the
  # restart that activates the new code, never after it. Between the drop and
  # the restart, the old worker names a column that no longer exists and TPC
  # writes fail; that window is the reason the two steps go together.
  #
  # Running this AFTER the restart would be worse than pointless: the new code
  # writes department_id only, so the re-link pass below would resurrect stale
  # strings over departments an admin had deliberately changed or cleared
  # through the CRUD.
  def up
    return unless column_exists?(:tpc_codes, :department)

    backfill_unlinked
    relink_edited
    report_unresolved

    remove_column :tpc_codes, :department
  end

  def down
    return if column_exists?(:tpc_codes, :department)

    add_column :tpc_codes, :department, :string, limit: 100

    execute "UPDATE tpc_codes t INNER JOIN departments d ON d.id = t.department_id " \
            "SET t.department = d.name"
  end

  private

  # Rows created through the old UI after 039 ran: the string is set and
  # department_id is null. Same grouping and find-or-create semantics as 039.
  def backfill_unlinked
    rows = select_all(
      "SELECT department, COUNT(*) AS n FROM tpc_codes " \
      "WHERE department IS NOT NULL AND department <> '' AND department_id IS NULL " \
      "GROUP BY department"
    ).to_a

    rows.group_by { |r| r['department'].to_s.strip.downcase }.each_value do |variants|
      canonical = variants.max_by { |r| r['n'].to_i }['department'].to_s.strip
      dept_id   = find_or_create_department(canonical)

      variants.each do |r|
        execute "UPDATE tpc_codes SET department_id = #{dept_id} " \
                "WHERE department = #{quote(r['department'])} AND department_id IS NULL"
      end
      say "linked #{variants.sum { |r| r['n'].to_i }} row(s) to #{canonical}", true
    end
  end

  # Rows EDITED through the old UI after 039 ran. The old code wrote only the
  # string, so a user changing a department left department_id pointing at the
  # previous one. backfill_unlinked cannot see these -- department_id is not
  # null -- so without this pass the edit is silently discarded and the string
  # holding the evidence is dropped in the same migration.
  def relink_edited
    mismatched = select_all(
      "SELECT t.id, t.department AS wanted, d.name AS linked " \
      "FROM tpc_codes t INNER JOIN departments d ON d.id = t.department_id " \
      "WHERE t.department IS NOT NULL AND t.department <> '' " \
      "AND LOWER(TRIM(t.department)) <> LOWER(TRIM(d.name))"
    ).to_a

    mismatched.each do |row|
      wanted  = row['wanted'].to_s.strip
      dept_id = find_or_create_department(wanted)

      execute "UPDATE tpc_codes SET department_id = #{dept_id} WHERE id = #{row['id'].to_i}"
      say "tpc_code #{row['id']}: relinked from #{row['linked']} to #{wanted} " \
          '(edited between 039 and 040)', true
    end
  end

  # Last look at the string column before it goes. Anything printed here is a
  # row whose department could not be represented in the new table; the output
  # is the only remaining record of it once the column is dropped.
  def report_unresolved
    orphans = select_all(
      "SELECT id, department FROM tpc_codes " \
      "WHERE department IS NOT NULL AND department <> '' AND department_id IS NULL"
    ).to_a

    if orphans.empty?
      say 'every departmented TPC code is linked; dropping the string column', true
    else
      orphans.each do |row|
        say "UNRESOLVED tpc_code #{row['id']}: #{row['department'].inspect} " \
            'could not be linked and is about to be dropped', true
      end
      raise ActiveRecord::IrreversibleMigration,
            "#{orphans.size} TPC code(s) still carry an unlinked department string. " \
            'Refusing to drop the column and lose them. Resolve them, then re-run.'
    end
  end

  def find_or_create_department(name)
    quoted = quote(name)
    existing = select_value("SELECT id FROM departments WHERE LOWER(name) = LOWER(#{quoted})")
    return existing if existing

    execute "INSERT INTO departments (name, created_at, updated_at) VALUES (#{quoted}, NOW(), NOW())"
    select_value('SELECT LAST_INSERT_ID()')
  end
end
