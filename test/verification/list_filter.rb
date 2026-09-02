abort 'REFUSING: production' if ActiveRecord::Base.connection.current_database == 'redmine'

FAILURES = []
def check(label)
  ok = yield
  puts format('  %-58s %s', label, ok ? 'PASS' : '*** FAIL ***')
  FAILURES << label unless ok
rescue StandardError => e
  puts format('  %-58s *** ERROR *** %s', label, "#{e.class}: #{e.message.lines.first.to_s.strip[0,60]}")
  FAILURES << label
end

ActiveRecord::Base.transaction do
  # This host runs other verification/test activity concurrently against
  # redmine_test, which has been observed to leave users/statuses briefly
  # empty between runs. Every fixture here is created fresh inside this
  # transaction, with a unique suffix, rather than relying on "first record
  # in the table" -- so this script does not race with whatever else is
  # touching the shared test database.
  suffix = "#{Process.pid}-#{Time.now.to_i}"

  project = Project.create!(name: "List Filter Verify #{suffix}", identifier: "list-filter-verify-#{suffix}")
  decoy_project = Project.create!(name: "List Filter Verify Decoy #{suffix}", identifier: "list-filter-verify-decoy-#{suffix}")
  status = PurchaseRequestStatus.create!(
    name: "List Filter Verify Status #{suffix}", position: 97, color: '#336699'
  )
  user = User.create!(
    firstname: 'List Filter', lastname: 'Verify', login: "list-filter-verify-#{suffix}",
    mail: "list-filter-verify-#{suffix}@example.net", status: 1
  )

  build_request = lambda do |overrides = {}|
    attrs = {
      project: project,
      status_id: status.id,
      user: user,
      priority: 'normal',
      title: 'At least five chars',
      description: 'At least ten characters.',
      estimated_price: 123
    }.merge(overrides)
    r = PurchaseRequest.new(attrs)
    r.write_attribute(:vendor, 'Acme Supplies')
    r
  end

  active = build_request.call
  active.save!

  to_cancel = build_request.call
  to_cancel.save!
  to_cancel.cancel!(user: user, reason: 'No longer needed')

  to_revise = build_request.call
  to_revise.save!
  to_revise.revise!(user: user)
  to_revise.reload

  decoy = build_request.call(project: decoy_project)
  decoy.save!
  decoy.cancel!(user: user, reason: 'Decoy cancellation')

  check('1a: for_lifecycle(nil) returns only active requests') do
    ids = PurchaseRequest.where(project: project).for_lifecycle(nil).pluck(:id)
    ids.include?(active.id) && !ids.include?(to_cancel.id) && !ids.include?(to_revise.id)
  end

  check("1b: for_lifecycle('') returns only active requests") do
    ids = PurchaseRequest.where(project: project).for_lifecycle('').pluck(:id)
    ids.include?(active.id) && !ids.include?(to_cancel.id) && !ids.include?(to_revise.id)
  end

  check("2: for_lifecycle('all') returns active, cancelled and superseded alike") do
    ids = PurchaseRequest.where(project: project).for_lifecycle('all').pluck(:id)
    ids.include?(active.id) && ids.include?(to_cancel.id) && ids.include?(to_revise.id)
  end

  check("3: for_lifecycle('cancelled') returns only the cancelled one") do
    ids = PurchaseRequest.where(project: project).for_lifecycle('cancelled').pluck(:id)
    ids == [to_cancel.id]
  end

  check("4: for_lifecycle('superseded') returns only the superseded one") do
    ids = PurchaseRequest.where(project: project).for_lifecycle('superseded').pluck(:id)
    ids == [to_revise.id]
  end

  check('5a: an unrecognised (nonsense) value falls back to active only') do
    ids = PurchaseRequest.where(project: project).for_lifecycle('nonsense').pluck(:id)
    ids.include?(active.id) && !ids.include?(to_cancel.id) && !ids.include?(to_revise.id)
  end

  check('5b: a SQL-injection-shaped value falls back to active only, and does not raise') do
    ids = PurchaseRequest.where(project: project).for_lifecycle("'; DROP TABLE purchase_requests; --").pluck(:id)
    ids.include?(active.id) && !ids.include?(to_cancel.id) && !ids.include?(to_revise.id)
  end

  check("6: composes with project scoping -- a project-scoped relation stays within the project after for_lifecycle('all')") do
    # project.purchase_requests (the association the controller actually
    # calls) cannot be exercised from `rails runner` on this host: the
    # host-application Project class is patched in from
    # lib/redmine_purchase_requests/patches/project_patch.rb via a
    # to_prepare hook, and that hook is only proven to fire under the
    # request/reloader cycle of a running server, not under `rails runner`
    # (confirmed directly: Project.reflect_on_association(:purchase_requests)
    # is nil in this process). `.where(project: project)` is the same SQL
    # shape `project.purchase_requests` would produce and is what checks 1-5
    # already rely on, so it is what is actually verifiable here.
    ids = PurchaseRequest.where(project: project).for_lifecycle('all').pluck(:id)
    ids.include?(active.id) && ids.include?(to_cancel.id) && ids.include?(to_revise.id) && !ids.include?(decoy.id)
  end

  check('7: for_lifecycle works on the class as well as on a real association') do
    # PurchaseRequestStatus#purchase_requests is a plain has_many defined on
    # the plugin's own model (see purchase_request_status.rb) rather than
    # patched onto a host class, so -- unlike project.purchase_requests --
    # it is reliably available here (lifecycle.rb already depends on this
    # same association resolving without error).
    class_ids = PurchaseRequest.for_lifecycle('all').pluck(:id)
    assoc_ids = status.purchase_requests.for_lifecycle('active').pluck(:id)
    class_ids.include?(decoy.id) &&
      assoc_ids.include?(active.id) &&
      !assoc_ids.include?(to_cancel.id) &&
      !assoc_ids.include?(to_revise.id) &&
      !assoc_ids.include?(decoy.id)
  end

  raise ActiveRecord::Rollback
end

puts FAILURES.empty? ? 'ALL PASS' : "#{FAILURES.size} FAILED: #{FAILURES.join(', ')}"
exit(FAILURES.empty? ? 0 : 1)
