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
  project = Project.first || Project.create!(name: 'Cancellation Verify', identifier: 'cancellation-verify')
  status = PurchaseRequestStatus.first || PurchaseRequestStatus.create!(
    name: 'Cancellation Verify Status', position: 1, color: '#336699'
  )
  user = User.first
  other_user = User.where.not(id: user.id).first || user

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

  check('1: cancel! sets lifecycle, cancelled_by, cancelled_at and reason') do
    r = build_request.call
    r.save!
    r.cancel!(user: other_user, reason: 'No longer needed')
    r.lifecycle == 'cancelled' &&
      r.cancelled_by_id == other_user.id &&
      r.cancelled_at.present? &&
      r.cancellation_reason == 'No longer needed'
  end

  check('2: cancelling leaves status_id untouched') do
    r = build_request.call
    r.save!
    status_before = r.status_id
    r.cancel!(user: other_user, reason: 'Budget cut')
    r.reload
    r.status_id == status_before
  end

  check('3: blank reason raises ArgumentError, request stays active') do
    r = build_request.call
    r.save!
    raised = false
    begin
      r.cancel!(user: other_user, reason: '   ')
    rescue ArgumentError
      raised = true
    end
    r.reload
    raised && r.active?
  end

  check('4: uncancel! returns to active and clears cancellation fields') do
    r = build_request.call
    r.save!
    r.cancel!(user: other_user, reason: 'Testing uncancel')
    r.uncancel!
    r.lifecycle == 'active' &&
      r.cancelled_by_id.nil? &&
      r.cancelled_at.nil? &&
      r.cancellation_reason.nil?
  end

  check('5: cancellable? is false and cancel! raises for a superseded request') do
    r = build_request.call
    r.lifecycle = 'superseded'
    r.save!
    raised = false
    begin
      r.cancel!(user: other_user, reason: 'Should not work')
    rescue StandardError
      raised = true
    end
    !r.cancellable? && raised
  end

  check('6: uncancellable? is false and uncancel! raises once superseded') do
    r = build_request.call
    r.save!
    r.cancel!(user: other_user, reason: 'Will be revised')

    successor = build_request.call(revision_of_id: r.id)
    successor.save!

    r.reload
    raised = false
    begin
      r.uncancel!
    rescue StandardError
      raised = true
    end
    !r.uncancellable? && raised
  end

  check('7: cancelling releases budget -- CAPEX utilized_amount drops by exactly the amount') do
    capex = Capex.create!(
      project: project, tpc_code: 'TPC-CANCEL-001', description: 'Cancellation verify capex',
      total_amount: 1000, currency: 'USD', year: 2026,
      q1_amount: 1000, q2_amount: 0, q3_amount: 0, q4_amount: 0
    )

    a = build_request.call(estimated_price: 100, capex_id: capex.id)
    a.save!
    b = build_request.call(estimated_price: 250, capex_id: capex.id)
    b.save!

    capex.reload
    before = capex.utilized_amount # 350

    b.cancel!(user: other_user, reason: 'Cancel to release budget')

    capex.reload
    after = capex.utilized_amount

    before == 350 && after == before - 250
  end

  raise ActiveRecord::Rollback
end

puts FAILURES.empty? ? 'ALL PASS' : "#{FAILURES.size} FAILED: #{FAILURES.join(', ')}"
exit(FAILURES.empty? ? 0 : 1)
