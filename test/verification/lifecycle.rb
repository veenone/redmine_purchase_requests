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
  project = Project.first || Project.create!(name: 'Lifecycle Verify', identifier: 'lifecycle-verify')
  status = PurchaseRequestStatus.first || PurchaseRequestStatus.create!(
    name: 'Lifecycle Verify Status', position: 1, color: '#336699'
  )
  user = User.first

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

  check('new PurchaseRequest defaults lifecycle to active') do
    r = build_request.call
    r.save!
    r.lifecycle == 'active' && r.active?
  end

  check('counts_toward_budget? is true when active') do
    r = build_request.call
    r.save!
    r.counts_toward_budget? == true
  end

  check('counts_toward_budget? is false when cancelled') do
    r = build_request.call
    r.lifecycle = 'cancelled'
    r.save!
    r.counts_toward_budget? == false
  end

  check('counts_toward_budget? is false when superseded') do
    r = build_request.call
    r.lifecycle = 'superseded'
    r.save!
    r.counts_toward_budget? == false
  end

  check('lifecycle: nonsense is invalid with error on :lifecycle') do
    r = build_request.call
    r.lifecycle = 'nonsense'
    !r.valid? && r.errors[:lifecycle].present?
  end

  check('PurchaseRequest.budgeted.to_sql includes active') do
    PurchaseRequest.budgeted.to_sql.include?('active')
  end

  check('PurchaseRequestStatus#purchase_requests.count does not raise') do
    PurchaseRequestStatus.first.purchase_requests.count
    true
  end

  raise ActiveRecord::Rollback
end

puts FAILURES.empty? ? 'ALL PASS' : "#{FAILURES.size} FAILED: #{FAILURES.join(', ')}"
exit(FAILURES.empty? ? 0 : 1)
