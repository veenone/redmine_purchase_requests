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
  project = Project.first || Project.create!(name: 'Revision Verify', identifier: 'revision-verify')
  status = PurchaseRequestStatus.first || PurchaseRequestStatus.create!(
    name: 'Revision Verify Status', position: 1, color: '#336699'
  )
  other_status = PurchaseRequestStatus.create!(
    name: 'Revision Verify Other Status', position: 98, color: '#993333'
  )

  # Two distinct real users so "user_id copied, not reassigned" (check 4) is
  # actually meaningful -- User.first in this database is a lazily-created
  # AnonymousUser, which is not enough to distinguish raiser from actor.
  raiser = User.create!(
    firstname: 'Revision', lastname: 'Raiser', login: 'revision-verify-raiser',
    mail: 'revision-verify-raiser@example.net', status: 1
  )
  actor = User.create!(
    firstname: 'Revision', lastname: 'Actor', login: 'revision-verify-actor',
    mail: 'revision-verify-actor@example.net', status: 1
  )

  build_request = lambda do |overrides = {}|
    attrs = {
      project: project,
      status_id: status.id,
      user: raiser,
      priority: 'normal',
      title: 'At least five chars',
      description: 'At least ten characters.',
      estimated_price: 123
    }.merge(overrides)
    r = PurchaseRequest.new(attrs)
    r.write_attribute(:vendor, 'Acme Supplies')
    r
  end

  check('1: revise! returns a persisted, active child linked by revision_of_id, revision_number + 1') do
    parent = build_request.call
    parent.save!
    child = parent.revise!(user: actor)
    child.persisted? && child.active? &&
      child.revision_of_id == parent.id &&
      child.revision_number == parent.revision_number + 1
  end

  check('2: the parent becomes superseded and parent.superseded_by is the child') do
    parent = build_request.call
    parent.save!
    child = parent.revise!(user: actor)
    parent.reload
    parent.superseded? && parent.superseded_by == child
  end

  check('3: child copies title/description/vendor/currency/priority/notes/capex/quarter/allocation') do
    capex = Capex.create!(
      project: project, tpc_code: 'TPC-REV-COPY-001', description: 'Revision copy verify capex',
      total_amount: 1000, currency: 'USD', year: 2026,
      q1_amount: 1000, q2_amount: 0, q3_amount: 0, q4_amount: 0
    )
    parent = build_request.call(
      title: 'Original title here', description: 'Original description text.',
      currency: 'EUR', priority: 'high', notes: 'Some important notes',
      capex_id: capex.id, allocated_quarter: 1, allocated_amount: 50, estimated_price: 100
    )
    parent.save!
    child = parent.revise!(user: actor)
    child.title == parent.title &&
      child.description == parent.description &&
      child.read_attribute(:vendor) == parent.read_attribute(:vendor) &&
      child.currency == parent.currency &&
      child.priority == parent.priority &&
      child.notes == parent.notes &&
      child.capex_id == parent.capex_id &&
      child.allocated_quarter == parent.allocated_quarter &&
      child.allocated_amount == parent.allocated_amount
  end

  check('4: user_id is copied, not reassigned to the revising user') do
    parent = build_request.call(user: raiser)
    parent.save!
    child = parent.revise!(user: actor)
    child.user_id == raiser.id && child.user_id != actor.id
  end

  check("5: the child's status_id is the default status, not the parent's") do
    parent = build_request.call(status_id: other_status.id)
    parent.save!
    raise 'fixture setup invalid: other_status collides with default' if parent.status_id == PurchaseRequestStatus.default&.id

    child = parent.revise!(user: actor)
    child.status_id == PurchaseRequestStatus.default&.id && child.status_id != parent.status_id
  end

  check('6: the child has no issue_id even when the parent has one') do
    issue_status = IssueStatus.create!(name: 'Revision Verify Issue Status')
    tracker = Tracker.create!(name: 'Revision Verify Tracker', default_status: issue_status)
    priority = IssuePriority.create!(name: 'Revision Verify Priority')

    parent_issue = Issue.new(
      project: project, tracker: tracker, status: issue_status, priority: priority,
      author: raiser, subject: 'Revision verify issue'
    )
    parent_issue.save!(validate: false)

    parent = build_request.call
    parent.save!
    parent.update_column(:issue_id, parent_issue.id)

    child = parent.revise!(user: actor)
    parent.issue_id.present? && child.issue_id.nil?
  end

  check('7: revising twice raises ActiveRecord::RecordNotUnique -- the database is the guard, not the model') do
    parent = build_request.call
    parent.save!
    parent.revise!(user: actor)

    # Bypass revisable? (which would refuse this long before the index does)
    # so the assertion is against the unique index on revision_of_id, the
    # thing that actually prevents a raced second revision.
    parent.update_column(:lifecycle, 'active')

    raised = nil
    begin
      parent.revise!(user: actor)
    rescue ActiveRecord::RecordNotUnique => e
      raised = e
    end
    raised.is_a?(ActiveRecord::RecordNotUnique)
  end

  check('8: revise! is atomic -- a child that cannot save leaves the parent active with no successor') do
    parent = build_request.call
    parent.save!

    # Mocha is unavailable on this host, so force the failure with a
    # singleton method on this instance: build_revision returns a bare,
    # unsavable PurchaseRequest instead of the normal copy.
    def parent.build_revision
      PurchaseRequest.new
    end

    raised = nil
    begin
      parent.revise!(user: actor)
    rescue ActiveRecord::RecordInvalid => e
      raised = e
    end

    parent.reload
    raised.is_a?(ActiveRecord::RecordInvalid) && parent.active? && parent.superseded_by.nil?
  end

  check('9: budget moves from parent to child -- CAPEX utilized_amount reflects only the child') do
    capex = Capex.create!(
      project: project, tpc_code: 'TPC-REV-BUDGET-001', description: 'Revision budget verify capex',
      total_amount: 1000, currency: 'USD', year: 2026,
      q1_amount: 1000, q2_amount: 0, q3_amount: 0, q4_amount: 0
    )
    parent = build_request.call(estimated_price: 100, capex_id: capex.id)
    parent.save!
    child = parent.revise!(user: actor)
    child.update!(estimated_price: 250)

    capex.reload
    capex.utilized_amount == 250
  end

  raise ActiveRecord::Rollback
end

puts FAILURES.empty? ? 'ALL PASS' : "#{FAILURES.size} FAILED: #{FAILURES.join(', ')}"
exit(FAILURES.empty? ? 0 : 1)
