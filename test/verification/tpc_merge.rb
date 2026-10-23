abort 'REFUSING: production' if ActiveRecord::Base.connection.current_database == 'redmine'

# A TPC number can legitimately exist twice -- once globally, once scoped to a
# project -- because TpcCode's uniqueness validation is scoped to project_id.
# The filter used to render that pair as two identical-looking entries, each
# matching only the records linked to its own row. These checks cover the
# grouping that collapses the pair into one entry, and the expansion that
# keeps the entry matching every underlying row.

FAILURES = []
def check(label)
  ok = yield
  puts format('  %-64s %s', label, ok ? 'PASS' : '*** FAIL ***')
  FAILURES << label unless ok
rescue StandardError => e
  puts format('  %-64s *** ERROR *** %s', label, "#{e.class}: #{e.message.lines.first.to_s.strip[0, 60]}")
  FAILURES << label
end

# Minimal includer: the concern needs #params and, for the scope bound,
# @project -- so this exercises it without booting a controller.
class FilterStub
  include RedminePurchaseRequests::TpcFilterable
  attr_reader :params

  def initialize(params, project = nil)
    @params = params
    @project = project if project
  end
end

ActiveRecord::Base.transaction do
  # Every fixture is created fresh inside this transaction with a unique
  # suffix rather than relying on "first record in the table", so this script
  # does not race with whatever else is touching the shared test database.
  suffix = "#{Process.pid}-#{Time.now.to_i}"
  number = "TPCVERIFY#{suffix}".delete('-').upcase

  project = Project.create!(name: "TPC Merge Verify #{suffix}", identifier: "tpc-merge-verify-#{suffix}")
  other   = Project.create!(name: "TPC Merge Other #{suffix}",  identifier: "tpc-merge-other-#{suffix}")
  dept    = Department.create!(name: "TPC Merge Dept #{suffix}")

  make = lambda do |attrs = {}|
    TpcCode.create!({
      tpc_number: number,
      tpc_owner_name: 'Test Owner',
      tpc_email: 'owner@example.com',
      is_active: true
    }.merge(attrs))
  end

  # --- normalisation -------------------------------------------------------

  check('1: casing and padding do not make a different code') do
    TpcCode.normalize_number(' TPC1969 ') == TpcCode.normalize_number('tpc1969')
  end

  # --- grouping ------------------------------------------------------------

  global = make.call(project: nil, tpc_name: 'Global Name', department: dept)
  scoped = make.call(project: project, tpc_name: nil, department: nil)

  entries = TpcCode.merged_for_filter(TpcCode.where(tpc_number: number))

  check('2: a global code and its project namesake collapse into one entry') do
    entries.size == 1 && entries.first.merged?
  end

  check('3: the merged entry carries every underlying id') do
    entries.first.group_ids.sort == [global.id, scoped.id].sort
  end

  check('4: the entry takes the project row id, so the checkbox value is unchanged') do
    entries.first.id == scoped.id
  end

  # The live data has exactly this shape: an imported project row with no
  # tpc_name beside a global row carrying the real one.
  check('5: a blank field on the project row falls back to the global row') do
    entry = entries.first
    entry.tpc_name == 'Global Name' &&
      entry.department == dept &&
      entry.display_name == "#{number} - Global Name"
  end

  check('6: a merged entry names every scope it covers') do
    entries.first.scope_display == "#{project.name} + Global"
  end

  check('7: untouched attributes still delegate to the leading row') do
    entries.first.tpc_email == scoped.tpc_email && entries.first.tpc_number == number
  end

  # --- which row's wording wins -------------------------------------------

  check('8: the project row leads, so its own wording wins over the global') do
    scoped.update!(tpc_name: 'Project Name')
    entry = TpcCode.merged_for_filter(TpcCode.where(tpc_number: number)).first
    won = entry.tpc_name == 'Project Name'
    scoped.update!(tpc_name: nil)
    won
  end

  # A dedicated code, because display_name prefers tpc_name and the group
  # above borrows one from its global row -- the owner would never surface.
  check('9: surrounding whitespace is stripped out of the displayed owner') do
    padded_owner = make.call(
      tpc_number: "#{number}W", project: nil,
      tpc_name: nil, tpc_owner_name: '  Gilbert ASUNCION  '
    )
    entry = TpcCode.merged_for_filter(TpcCode.where(id: padded_owner.id)).first
    entry.display_name == "#{number}W - Gilbert ASUNCION"
  end

  # --- codes that must NOT be grouped -------------------------------------

  solo   = make.call(tpc_number: "#{number}A", project: nil)
  prefix = make.call(tpc_number: "#{number}AB", project: nil)

  check('10: a code with no namesake is left alone and is its own group') do
    entry = TpcCode.merged_for_filter(TpcCode.where(tpc_number: "#{number}A")).first
    !entry.merged? && entry.group_ids == [solo.id]
  end

  check('11: a plain row reports itself as its own group') do
    solo.group_ids == [solo.id]
  end

  check('12: codes that merely start alike are not grouped together') do
    TpcCode.merged_for_filter(
      TpcCode.where(tpc_number: ["#{number}A", "#{number}AB"])
    ).size == 2 && prefix.present?
  end

  # --- sibling expansion ---------------------------------------------------
  #
  # The filter submits only the entry's leading id. Records link to one
  # specific row, so the concern must widen that back out to the whole group.

  check('13: selecting the project id expands to include the global row') do
    ids = FilterStub.new({ tpc_code_id: [scoped.id.to_s] }).expanded_tpc_code_ids
    ids.map(&:to_i).sort == [global.id, scoped.id].sort
  end

  check('14: expansion works from either side of the pair') do
    ids = FilterStub.new({ tpc_code_id: [global.id.to_s] }).expanded_tpc_code_ids
    ids.map(&:to_i).sort == [global.id, scoped.id].sort
  end

  check('15: both ids reach the generated SQL') do
    sql = FilterStub.new({ tpc_code_id: [scoped.id.to_s] }).apply_tpc_filter(PurchaseRequest.all).to_sql
    sql.include?(scoped.id.to_s) && sql.include?(global.id.to_s)
  end

  check('16: a record linked to the sibling row counts as selected') do
    FilterStub.new({ tpc_code_id: [scoped.id.to_s] }).tpc_selected?(global.id)
  end

  check('17: an unrelated code is still not selected') do
    !FilterStub.new({ tpc_code_id: [scoped.id.to_s] }).tpc_selected?(solo.id)
  end

  check('18: case and padding differences still count as the same code') do
    padded = make.call(tpc_number: " #{number.downcase} ", project: other)
    ids = FilterStub.new({ tpc_code_id: [scoped.id.to_s] }).expanded_tpc_code_ids
    ids.include?(padded.id.to_s)
  end

  # Unbounded, filtering inside one project would pull in another project's
  # same-numbered code and surface rows the user cannot see.
  check('19: expansion stays inside the visible scope when a project is set') do
    foreign = TpcCode.where(tpc_number: " #{number.downcase} ").first
    ids = FilterStub.new({ tpc_code_id: [scoped.id.to_s] }, project).expanded_tpc_code_ids
    ids.include?(global.id.to_s) && !ids.include?(foreign.id.to_s)
  end

  # An id matching nothing must keep filtering to nothing. Dropping it would
  # turn a filter that should be empty into an unfiltered list.
  check('20: an id matching no row is passed through rather than dropped') do
    missing = (TpcCode.maximum(:id) || 0) + 1000
    FilterStub.new({ tpc_code_id: [missing.to_s] }).expanded_tpc_code_ids == [missing.to_s]
  end

  check('21: no filter means no expansion and an untouched scope') do
    stub = FilterStub.new({})
    stub.expanded_tpc_code_ids == [] &&
      !stub.apply_tpc_filter(PurchaseRequest.all).to_sql.include?('tpc_code_id')
  end

  check('22: TpcCode listings still filter on id rather than the association') do
    sql = FilterStub.new({ tpc_code_id: [scoped.id.to_s] }).apply_tpc_filter(TpcCode.all, column: :id).to_sql
    sql.include?('tpc_codes') && !sql.include?('tpc_code_id')
  end

  # --- end to end: the results a filtered list would return ----------------

  check('23: filtering by the merged entry returns records linked to BOTH rows') do
    status = PurchaseRequestStatus.create!(
      name: "TPC Merge Verify Status #{suffix}", position: 96, color: '#336699'
    )
    user = User.create!(
      firstname: 'TPC Merge', lastname: 'Verify', login: "tpc-merge-verify-#{suffix}",
      mail: "tpc-merge-verify-#{suffix}@example.net", status: 1
    )
    build = lambda do |tpc|
      r = PurchaseRequest.new(
        project: project, status_id: status.id, user: user, priority: 'normal',
        title: 'At least five chars', description: 'At least ten characters.',
        estimated_price: 100, tpc_code_id: tpc.id
      )
      r.write_attribute(:vendor, 'Acme Supplies')
      r.save!
      r
    end

    on_scoped = build.call(scoped)
    on_global = build.call(global)

    found = FilterStub.new({ tpc_code_id: [scoped.id.to_s] }, project)
                      .apply_tpc_filter(PurchaseRequest.where(project: project))
                      .pluck(:id)

    found.include?(on_scoped.id) && found.include?(on_global.id)
  end

  raise ActiveRecord::Rollback
end

puts FAILURES.empty? ? 'ALL PASS' : "#{FAILURES.size} FAILED: #{FAILURES.join(', ')}"
exit(FAILURES.empty? ? 0 : 1)
