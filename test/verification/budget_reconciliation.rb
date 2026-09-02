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
  project = Project.first || Project.create!(name: 'Budget Reconciliation Verify', identifier: 'budget-reconciliation-verify')
  status = PurchaseRequestStatus.first || PurchaseRequestStatus.create!(
    name: 'Budget Reconciliation Verify Status', position: 1, color: '#336699'
  )
  user = User.first
  opex_category = OpexCategory.first || OpexCategory.create!(name: 'Budget Reconciliation Verify Category', position: 1)

  capex = Capex.create!(
    project: project, tpc_code: 'TPC-BRC-001', description: 'Budget reconciliation verify capex',
    total_amount: 1000, currency: 'USD', year: 2026,
    q1_amount: 1000, q2_amount: 0, q3_amount: 0, q4_amount: 0
  )

  opex = Opex.create!(
    project: project, category_id: opex_category.id, description: 'Budget reconciliation verify opex',
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
    r.save!
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
    r.save!
    r
  end

  # --- CAPEX fixture: three linked requests, one cancelled ---
  c1 = build_capex_request.call(estimated_price: 100)
  c2 = build_capex_request.call(estimated_price: 200)
  c3 = build_capex_request.call(estimated_price: 300)
  c3.update!(lifecycle: 'cancelled')

  check('1: capex utilized_amount excludes the cancelled request (100 + 200 = 300)') do
    capex.reload
    capex.utilized_amount == 300
  end

  check('2: @purchase_requests.count is still 3 -- the list and the total legitimately differ') do
    scoped = capex.purchase_requests.includes(:user, :status)
    scoped.count == 3
  end

  check('3: counting = @purchase_requests.count(&:counts_toward_budget?) is 2, the number the heading shows') do
    scoped = capex.purchase_requests.includes(:user, :status)
    scoped.count(&:counts_toward_budget?) == 2
  end

  check('4: count(&block) followed by each on the same relation issues no extra query') do
    scoped = capex.purchase_requests.includes(:user, :status)
    counting = scoped.count(&:counts_toward_budget?) # loads + caches the relation
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      scoped.each { |pr| pr.counts_toward_budget? }
    end
    counting == 2 && queries.zero?
  end

  # --- OPEX fixture: its own linked requests, to prove the OPEX side is not merely assumed ---
  o1 = build_opex_request.call(estimated_price: 50)
  o2 = build_opex_request.call(estimated_price: 150)
  o3 = build_opex_request.call(estimated_price: 250)
  o3.update!(lifecycle: 'cancelled')

  check('5: opex linked_requests count is still 3 -- the list and the total legitimately differ') do
    linked = opex.purchase_requests.includes(:user, :status)
    linked.count == 3
  end

  check('6: opex counting = linked_requests.count(&:counts_toward_budget?) is 2, the number the heading shows') do
    linked = opex.purchase_requests.includes(:user, :status)
    linked.count(&:counts_toward_budget?) == 2
  end

  check('7: opex utilized_amount excludes the cancelled request (50 + 150 = 200)') do
    opex.reload
    opex.utilized_amount == 200
  end

  raise ActiveRecord::Rollback
end

puts FAILURES.empty? ? 'ALL PASS' : "#{FAILURES.size} FAILED: #{FAILURES.join(', ')}"
exit(FAILURES.empty? ? 0 : 1)
