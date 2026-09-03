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
  project = Project.first || Project.create!(name: 'Lifecycle Views Verify', identifier: 'lifecycle-views-verify')
  status = PurchaseRequestStatus.first || PurchaseRequestStatus.create!(
    name: 'Lifecycle Views Verify Status', position: 1, color: '#336699'
  )
  user = User.first
  actor = User.create!(
    firstname: 'Lifecycle Views', lastname: 'Actor', login: 'lifecycle-views-verify-actor',
    mail: 'lifecycle-views-verify-actor@example.net', status: 1
  )

  build_request = lambda do
    r = PurchaseRequest.new(
      project: project, status_id: status.id, user: user, priority: 'normal',
      title: 'At least five chars', description: 'At least ten characters.',
      estimated_price: 123
    )
    r.write_attribute(:vendor, 'Acme Supplies')
    r.save!
    r
  end

  render_banner = lambda do |request_record|
    ApplicationController.render(
      partial: 'purchase_requests/lifecycle_banner',
      locals: { request_record: request_record }
    )
  end

  check('1: _lifecycle_banner renders blank/whitespace-only for an active request') do
    active = build_request.call
    html = render_banner.call(active)
    html.strip.empty?
  end

  check("2: _lifecycle_banner for a cancelled request includes the reason and the canceller's name") do
    cancelled = build_request.call
    cancelled.cancel!(user: actor, reason: 'Budget cut this quarter')
    html = render_banner.call(cancelled)
    html.include?('Budget cut this quarter') && html.include?(actor.name)
  end

  check("3: _lifecycle_banner for a superseded request includes the successor's id") do
    parent = build_request.call
    child = parent.revise!(user: actor)
    parent.reload
    html = render_banner.call(parent)
    html.include?(child.id.to_s)
  end

  raise ActiveRecord::Rollback
end

puts FAILURES.empty? ? 'ALL PASS' : "#{FAILURES.size} FAILED: #{FAILURES.join(', ')}"
exit(FAILURES.empty? ? 0 : 1)
