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
  project = Project.first || Project.create!(name: 'Budget Rollback Verify', identifier: 'budget-rollback-verify')
  status = PurchaseRequestStatus.first || PurchaseRequestStatus.create!(
    name: 'Budget Rollback Verify Status', position: 1, color: '#336699'
  )
  closed_status = PurchaseRequestStatus.create!(
    name: 'Budget Rollback Verify Closed Status', position: 99, color: '#993333', is_closed: true
  )
  user = User.first
  opex_category = OpexCategory.first || OpexCategory.create!(name: 'Budget Rollback Verify Category', position: 1)

  capex = Capex.create!(
    project: project, tpc_code: 'TPC-BRV-001', description: 'Budget rollback verify capex',
    total_amount: 1000, currency: 'USD', year: 2026,
    q1_amount: 1000, q2_amount: 0, q3_amount: 0, q4_amount: 0
  )

  opex = Opex.create!(
    project: project, category_id: opex_category.id, description: 'Budget rollback verify opex',
    total_amount: 500, currency: 'USD', year: 2026,
    q1_amount: 500, q2_amount: 0, q3_amount: 0, q4_amount: 0
  )

  build_capex_request = lambda do |overrides = {}|
    attrs = {
      project: project, status_id: status.id, user: user, priority: 'normal',
      title: 'At least five chars', description: 'At least ten characters.',
      estimated_price: 100, currency: 'USD', capex_id: capex.id
    }.merge(overrides)
    r = PurchaseRequest.new(attrs)
    r.write_attribute(:vendor, 'Acme Supplies')
    r
  end

  build_opex_request = lambda do |overrides = {}|
    attrs = {
      project: project, status_id: status.id, user: user, priority: 'normal',
      title: 'At least five chars', description: 'At least ten characters.',
      estimated_price: 100, currency: 'USD', opex_id: opex.id, category_id: opex_category.id
    }.merge(overrides)
    r = PurchaseRequest.new(attrs)
    r.write_attribute(:vendor, 'Acme Supplies')
    r
  end

  r100 = build_capex_request.call(estimated_price: 100)
  r100.save!
  r250 = build_capex_request.call(estimated_price: 250)
  r250.save!
  r400 = build_capex_request.call(estimated_price: 400)
  r400.save!

  check('1: Capex#utilized_amount sums three active linked requests to 750') do
    capex.reload
    capex.utilized_amount == 750 && capex.remaining_amount == capex.total_amount - 750
  end

  check('2: cancelling the 400 request drops utilized_amount to 350, remaining +400') do
    capex.reload
    remaining_before = capex.remaining_amount # 250
    r400.update!(lifecycle: 'cancelled')
    capex.reload
    capex.utilized_amount == 350 && (capex.remaining_amount - remaining_before) == 400
  end

  r_superseded = build_capex_request.call(estimated_price: 50)
  r_superseded.save!

  check('3: a superseded request also stops counting') do
    capex.reload
    with_it_active = capex.utilized_amount # 350 + 50 = 400
    r_superseded.update!(lifecycle: 'superseded')
    capex.reload
    with_it_active == 400 && capex.utilized_amount == 350
  end

  check('4: a closed-status request still counts toward budget') do
    capex.reload
    before = capex.utilized_amount # 350
    r_closed = build_capex_request.call(estimated_price: 75, status_id: closed_status.id)
    r_closed.save!
    r_closed.closed? && r_closed.active? or raise 'fixture setup invalid: expected closed status + active lifecycle'
    capex.reload
    capex.utilized_amount == before + 75
  end

  check('5: PurchaseRequest.committed_sum excludes non-active requests') do
    a = build_capex_request.call(estimated_price: 60)
    a.save!
    b = build_capex_request.call(estimated_price: 40)
    b.lifecycle = 'cancelled'
    b.save!
    PurchaseRequest.committed_sum(PurchaseRequest.where(id: [a.id, b.id])) == 60
  end

  check('6: summing a preloaded Capex issues no queries (N+1 guard)') do
    preloaded = Capex.includes(:purchase_requests).find(capex.id)
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      preloaded.utilized_amount
    end
    queries.zero?
  end

  o1 = build_opex_request.call(estimated_price: 200)
  o1.save!
  o2 = build_opex_request.call(estimated_price: 300)
  o2.save!

  check('7: Opex#utilized_amount also excludes a cancelled request (parity with Capex)') do
    opex.reload
    before = opex.utilized_amount # 500
    o2.update!(lifecycle: 'cancelled')
    opex.reload
    before == 500 && opex.utilized_amount == 200
  end

  raise ActiveRecord::Rollback
end

puts FAILURES.empty? ? 'ALL PASS' : "#{FAILURES.size} FAILED: #{FAILURES.join(', ')}"
exit(FAILURES.empty? ? 0 : 1)
