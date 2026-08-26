# Renders the CAPEX and OPEX dashboards with each controller's real computed
# assigns and writes the HTML to disk, so a refactor can be proved output-
# identical. Run via:
#   RAILS_ENV=production bundle exec rails runner \
#     plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture before
require 'fileutils'

MODE   = ARGV[0]
TAG_A  = ARGV[1]
TAG_B  = ARGV[2]
ROOT   = Rails.root.join('tmp', 'dashboard_snapshots')

# Fixtures: [name, controller, project, params, setup]
#
# `setup` is an optional lambda that seeds the rows a branch needs. Seeded
# fixtures run inside a transaction that is rolled back after the HTML is
# captured, so the database is left exactly as it was found.
#
# Why they exist: the four unseeded fixtures only ever exercise the
# single-currency, exchange-rates-off, totals-reliable path. Every other branch
# on these dashboards — over budget, exactly 100%, mixed currency with rates
# off, a currency with no configured rate — was gated by nothing at all, and
# those are precisely the branches where the bugs have historically lived.
def base_project
  proj = Project.joins(:enabled_modules)
                .where(enabled_modules: { name: 'purchase_requests' })
                .first
  raise 'no project with purchase_requests enabled' unless proj
  proj
end

SEED_YEAR = 2099  # far outside real data, so seeded rows can never collide

def seed_capex(project, attrs)
  Capex.create!({
    project: project, year: SEED_YEAR, description: 'snapshot fixture',
    tpc_code: 'FIX-1', total_amount: 1000, currency: 'EUR',
    q1_amount: 250, q2_amount: 250, q3_amount: 250, q4_amount: 250
  }.merge(attrs))
end

def seed_opex(project, attrs)
  cat = OpexCategory.first || OpexCategory.create!(name: 'Fixture')
  Opex.create!({
    project: project, year: SEED_YEAR, description: 'snapshot fixture',
    opex_code: 'FIX-1', total_amount: 1000, currency: 'EUR', category_id: cat.id,
    q1_amount: 250, q2_amount: 250, q3_amount: 250, q4_amount: 250
  }.merge(attrs))
end

# A linked purchase request is how utilized_amount becomes non-zero.
def seed_request(project, budget, price, currency)
  status = PurchaseRequestStatus.first || raise('no purchase request status defined')
  pr = PurchaseRequest.new(
    project: project, title: 'snapshot fixture', status: status,
    user: User.current, estimated_price: price, currency: currency
  )
  pr.capex = budget if budget.is_a?(Capex)
  pr.opex  = budget if budget.is_a?(Opex)
  pr.save!(validate: false)
  pr
end

# Some branches are only reachable with plugin settings flipped (conversion
# on). Settings are global, so they are restored in an ensure block — a
# fixture must never leave configuration behind.
def with_settings(overrides)
  key = 'plugin_redmine_purchase_requests'
  original = Setting.send(key).dup
  merged = original.merge(overrides)
  Setting.send("#{key}=", merged)
  yield
ensure
  Setting.send("#{key}=", original)
end

def fixtures
  proj = base_project
  years = (Capex.pluck(:year) + Opex.pluck(:year)).compact.reject { |y| y == SEED_YEAR }.sort
  y_data  = years.last || Date.current.year
  y_empty = (years.max || Date.current.year) + 5
  sy = { year: SEED_YEAR.to_s }
  [
    ['capex_data',  CapexController, proj, { year: y_data.to_s }, nil],
    ['capex_empty', CapexController, proj, { year: y_empty.to_s }, nil],
    ['opex_data',   OpexController,  proj, { year: y_data.to_s }, nil],
    ['opex_empty',  OpexController,  proj, { year: y_empty.to_s }, nil],

    # utilized 1500 against a 1000 budget: danger tile, "Over budget by",
    # full danger ring (an arc with coincident endpoints paints nothing).
    ['capex_over', CapexController, proj, sy, -> (p) {
      c = seed_capex(p, {}); seed_request(p, c, 1500, 'EUR') }],
    ['opex_over',  OpexController,  proj, sy, -> (p) {
      o = seed_opex(p, {}); seed_request(p, o, 1500, 'EUR') }],

    # exactly 100%: the full-circle branch, distinct from >100%.
    ['capex_exactly_100', CapexController, proj, sy, -> (p) {
      c = seed_capex(p, {}); seed_request(p, c, 1000, 'EUR') }],

    # two currencies with conversion off: totals are a sum of unlike units,
    # so the reliability banner shows and no severity may be derived.
    ['capex_mixed_currency', CapexController, proj, sy, -> (p) {
      seed_capex(p, { currency: 'EUR', tpc_code: 'FIX-1' })
      seed_capex(p, { currency: 'USD', tpc_code: 'FIX-2' }) }],
    ['opex_mixed_currency',  OpexController,  proj, sy, -> (p) {
      seed_opex(p, { currency: 'EUR', opex_code: 'FIX-1' })
      seed_opex(p, { currency: 'USD', opex_code: 'FIX-2' }) }],

    # a currency with no rate in any lookup table: convert_capex_currency
    # silently falls back to 1.0, so the page must say the total is not
    # convertible rather than claim it was converted.
    # Reachable only with conversion ON: with it off, unconvertible_currencies
    # is empty by construction and this branch cannot fire.
    ['capex_missing_rate', CapexController, proj, sy, -> (p) {
      seed_capex(p, { currency: 'JPY' }) }, { 'capex_use_exchange_rates' => '1' }],

    # Unreliable totals AND a deficit. This combination is the one that hid a
    # sign inversion: over_budget is forced false when totals are unreliable,
    # so an unguarded .abs printed a deficit as a positive "Remaining".
    # Neither the over-budget fixtures (reliable) nor the missing-rate fixture
    # (in surplus) reach it.
    ['capex_unreliable_deficit', CapexController, proj, sy, -> (p) {
      c = seed_capex(p, { currency: 'JPY', total_amount: 1000 })
      seed_request(p, c, 1500, 'JPY') }, { 'capex_use_exchange_rates' => '1' }],

    # OPEX with conversion ON. Without this, OPEX's convert lambda is the
    # identity function in every fixture and the whole converted path — tiles
    # AND the quarterly breakdown that must use the same arithmetic — is
    # exercised by nothing.
    ['opex_rates_on', OpexController, proj, sy, -> (p) {
      seed_opex(p, { currency: 'USD', total_amount: 1000,
                     q1_amount: 400, q2_amount: 200, q3_amount: 200, q4_amount: 200 })
    }, { 'opex_exchange_rates' => { SEED_YEAR.to_s => { 'USD' => 2 } } }]
  ]
end

def render_one(controller_class, project, params, normalize_ids: false)
  c = controller_class.new
  request = ActionDispatch::TestRequest.create
  request.path_parameters[:controller] = controller_class.controller_path
  request.path_parameters[:action] = 'dashboard'
  params.each { |k, v| request.path_parameters[k] = v }
  c.set_request!(request)
  c.set_response!(controller_class.make_response!(request))
  c.instance_variable_set(:@project, project)
  User.current = User.active.where(admin: true).first
  c.send(:dashboard)
  dir = controller_class.name.sub('Controller', '').underscore
  view = c.view_context
  view.lookup_context.prefixes = [dir]
  html = view.render(template: "#{dir}/dashboard", layout: false)
  html = normalize(html)
  # Seeded fixtures live inside a rolled-back transaction, but the rollback
  # does NOT give back the auto-increment ids it consumed — so record ids
  # differ on every run and the fixture would be permanently red. Normalise
  # them for seeded fixtures ONLY; the real fixtures keep a strict gate that
  # would catch a genuine href change.
  html = html.gsub(%r{(/(?:capex|opex)/)\d+}, '\\1ID') if normalize_ids
  html
rescue => e
  "RENDER-ERROR #{e.class}: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
end

# Redmine's ApplicationHelper#form_tag_html stamps every <form> with a
# name="<id-or-form>-<8 hex chars>" attribute via SecureRandom.hex(4) (a
# workaround for https://bugzilla.mozilla.org/show_bug.cgi?id=1279253). That
# makes the attribute change on every single render regardless of any code
# change, which would otherwise show up as a permanent, meaningless DIFF.
# Normalize it away so the harness only reports diffs that reflect real
# output changes.
#
# Scoped to the <form ...> tag specifically, not to any element's `name`
# attribute: an unscoped match on /name="...[0-9a-f]{8}"/ would also catch
# a purely-decimal value (0-9 is a subset of [0-9a-f]), e.g. a future
# name="foo-12345678" built from a database id, and silently normalize away
# a genuine diff.
def normalize(html)
  html.gsub(/<form\b[^>]*>/) do |form_tag|
    form_tag.sub(/name="[a-zA-Z0-9_]*-[0-9a-f]{8}"/, 'name="RANDOMIZED"')
  end
end

case MODE
when 'capture'
  dir = ROOT.join(TAG_A)
  FileUtils.mkdir_p(dir)
  User.current = User.active.where(admin: true).first
  fixtures.each do |name, klass, proj, params, setup, settings|
    html = nil
    if setup
      # Seeded fixtures create the rows a branch needs, render, then roll the
      # whole thing back — the database must be left exactly as it was found.
      run = lambda do
        ActiveRecord::Base.transaction do
          setup.call(proj)
          html = render_one(klass, proj, params, normalize_ids: true)
          raise ActiveRecord::Rollback
        end
      end
      settings ? with_settings(settings) { run.call } : run.call
    else
      html = render_one(klass, proj, params)
    end
    html ||= 'RENDER-ERROR fixture produced no output'
    File.write(dir.join("#{name}.html"), html)
    puts "  captured #{name} (#{html.bytesize} bytes)#{' *** RENDER-ERROR ***' if html.start_with?('RENDER-ERROR')}"
  end
  leaked = Capex.where(year: SEED_YEAR).count + Opex.where(year: SEED_YEAR).count
  abort "FIXTURE LEAK: #{leaked} seeded rows survived rollback — refusing to continue" if leaked > 0
  puts "wrote #{dir}"
when 'compare'
  a = ROOT.join(TAG_A); b = ROOT.join(TAG_B)
  differing = []
  Dir[a.join('*.html')].sort.each do |fa|
    name = File.basename(fa)
    fb = b.join(name)
    unless File.exist?(fb)
      puts "MISSING in #{TAG_B}: #{name}"; differing << name; next
    end
    if File.read(fa) == File.read(fb)
      puts "  same  #{name}"
    else
      puts "  DIFF  #{name}"
      differing << name
      puts `diff -u #{fa} #{fb} | head -80`
    end
  end
  puts differing.empty? ? "\nALL IDENTICAL" : "\nDIFFERING: #{differing.join(', ')}"
  exit(differing.empty? ? 0 : 1)
else
  abort "usage: dashboard_snapshot.rb capture <tag> | compare <tagA> <tagB>"
end
