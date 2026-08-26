# Shared Budget Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make it structurally impossible for a fix to land on the CAPEX budget dashboard and miss the OPEX one, by rendering both from a shared shell fed by a shared concern.

**Architecture:** A `BudgetDashboard` controller concern computes the figures once (totals, severity, currency reliability) and takes a per-model currency converter, because CAPEX and OPEX genuinely use different conversion arithmetic. A shared shell partial owns the five sections both pages legitimately share; the grouping section and entries table stay per-model sub-partials the shell renders. Rollout is three separately revertible steps, OPEX last, verified by diffing rendered HTML rather than by assertions.

**Tech Stack:** Ruby 3.2, Rails 7.2 (Redmine 6.0.7 plugin), ERB, plain ES5 inline JS, Sprockets. **No test framework exists in this plugin** — verification is an HTML-diff harness (Task 1).

**Spec:** `docs/superpowers/specs/2026-08-26-shared-budget-dashboard-design.md`

## Global Constraints

- Ruby 3.2.0, Rails 7.2.2.2, Redmine 6.0.7. Plugin autoloads from `app/`.
- **No test framework.** Do not add one. Verification is the Task 1 harness plus: ERB compile, `ruby -c`, `node --check`, locale-key resolution, detector, `pr-*--modifier` audit.
- **Every CSS/JS/asset change requires** `RAILS_ENV=production bundle exec rake assets:precompile` and `touch /opt/redmine/tmp/restart.txt` before it is visible. Controller/view/locale changes need only the restart.
- **Line endings are load-bearing.** `config/locales/en.yml` and `app/models/opex.rb` are CRLF; everything else is LF. Never rewrite a whole file with a script that normalises endings. Before every commit run the line-ending audit in Task 1 Step 6.
- Colour contract (DESIGN.md): `green = utilized`, `amber = remaining`, `red = over budget`, `violet = TPC identity / utilization %`, `indigo = the one pointer`.
- Money rule: the label carries the direction ("Over budget by"), the number carries the magnitude (`.abs`).
- Severity: `high` when over budget, `medium` at ≥80%, else `low`. `over_budget` must be false whenever totals are unreliable.
- All user-visible strings go through `l()`. Reuse Redmine core keys (`button_edit`, `button_delete`, `button_view`, `text_are_you_sure`, `field_description`, `field_currency`) before minting new ones.
- **Do not change what either dashboard shows**, except where OPEX gains behaviour CAPEX already has.

---

## File Structure

**Create:**
- `app/controllers/concerns/budget_dashboard.rb` — figure computation, shared by both controllers
- `app/views/shared/_budget_dashboard.html.erb` — the shared shell
- `app/views/capex/_grouping.html.erb`, `app/views/capex/_entries_table.html.erb`
- `app/views/opex/_grouping.html.erb`, `app/views/opex/_entries_table.html.erb`
- `script/dashboard_snapshot.rb` — the HTML-diff harness (dev tool, committed)

**Modify:**
- `app/controllers/capex_controller.rb:94-256` (`dashboard`)
- `app/controllers/opex_controller.rb:106-187` (`dashboard`)
- `app/views/capex/dashboard.html.erb` — becomes a thin wrapper
- `app/views/opex/dashboard.html.erb` — becomes a thin wrapper

---

### Task 1: HTML-diff harness

Nothing else is safe without this. It is the substitute for a test suite: it renders each dashboard with its controller's real computed assigns and writes the HTML to disk, so later tasks can prove output is unchanged.

**Files:**
- Create: `script/dashboard_snapshot.rb`
- Create: `tmp/dashboard_snapshots/` (gitignored output dir)

**Interfaces:**
- Consumes: nothing.
- Produces: `ruby script/dashboard_snapshot.rb capture <tag>` writes `tmp/dashboard_snapshots/<tag>/<fixture>.html`; `... compare <tagA> <tagB>` prints a unified diff per fixture and exits non-zero if any differ.

- [ ] **Step 1: Write the harness**

Create `script/dashboard_snapshot.rb`:

```ruby
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

# Fixtures: [name, controller, project_identifier, params]
def fixtures
  proj = Project.joins(:enabled_modules)
                .where(enabled_modules: { name: 'purchase_requests' })
                .first
  raise 'no project with purchase_requests enabled' unless proj
  years = (Capex.pluck(:year) + Opex.pluck(:year)).compact.uniq.sort
  y_data    = years.last || Date.current.year
  y_empty   = (years.max || Date.current.year) + 5
  [
    ['capex_data',  CapexController, proj, { year: y_data.to_s }],
    ['capex_empty', CapexController, proj, { year: y_empty.to_s }],
    ['opex_data',   OpexController,  proj, { year: y_data.to_s }],
    ['opex_empty',  OpexController,  proj, { year: y_empty.to_s }]
  ]
end

def render_one(controller_class, project, params)
  c = controller_class.new
  c.instance_variable_set(:@project, project)
  request = ActionDispatch::TestRequest.create
  request.params.merge!(params)
  c.set_request!(request)
  c.set_response!(controller_class.make_response!(request))
  c.params.merge!(params)
  User.current = User.active.where(admin: true).first
  c.send(:dashboard)
  view = c.view_context
  controller_class.name.sub('Controller', '').underscore.tap do |dir|
    return view.render(template: "#{dir}/dashboard", layout: false)
  end
rescue => e
  "RENDER-ERROR #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
end

case MODE
when 'capture'
  dir = ROOT.join(TAG_A)
  FileUtils.mkdir_p(dir)
  fixtures.each do |name, klass, proj, params|
    html = render_one(klass, proj, params)
    File.write(dir.join("#{name}.html"), html)
    puts "  captured #{name} (#{html.bytesize} bytes)#{' *** RENDER-ERROR ***' if html.start_with?('RENDER-ERROR')}"
  end
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
```

- [ ] **Step 2: Run it and confirm it renders without RENDER-ERROR**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture baseline 2>&1 | grep -v 'warning:'
```

Expected: four `captured …` lines, none containing `*** RENDER-ERROR ***`.

If a fixture reports RENDER-ERROR, **stop and fix the harness before any refactor** — a harness that cannot render is worse than none, because later "no diff" results would be meaningless.

- [ ] **Step 3: Prove the harness detects a change**

Temporarily append a marker to the CAPEX view, re-capture, compare, then revert:

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
printf '\n<!-- HARNESS SELF TEST -->\n' >> app/views/capex/dashboard.html.erb
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture selftest 2>&1 | grep -v 'warning:'
RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb compare baseline selftest 2>&1 | grep -v 'warning:'
cd /opt/redmine/plugins/redmine_purchase_requests && git checkout app/views/capex/dashboard.html.erb
```

Expected: `DIFF capex_data.html` and exit status 1. A harness that reports ALL IDENTICAL here is broken.

- [ ] **Step 4: Gitignore the snapshot output**

Append to `.gitignore` (preserve its existing line endings — check with `file .gitignore` first):

```
tmp/dashboard_snapshots/
```

- [ ] **Step 5: Re-capture a clean baseline**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture baseline 2>&1 | grep -v 'warning:'
```

- [ ] **Step 6: Record the standing pre-commit audit**

Every subsequent task ends with this. Run it now to confirm it passes on a clean tree:

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
for f in $(git diff --name-only HEAD); do
  now=$(file -b "$f" | grep -q CRLF && echo CRLF || echo LF)
  orig=$(git show HEAD:"$f" | file -b - | grep -q CRLF && echo CRLF || echo LF)
  [ "$now" = "$orig" ] || echo "LINE-ENDING MISMATCH: $f ($orig -> $now)"
done; echo "line-ending audit done"
```

- [ ] **Step 7: Commit**

```bash
git add script/dashboard_snapshot.rb .gitignore
git commit -m "test: add HTML-diff harness for the budget dashboards

The plugin has no test framework, so refactors of these two live pages are
verified by rendering each dashboard with its controller's real computed
assigns and diffing the HTML. Self-tested: an injected marker is detected."
```

---

### Task 2: `BudgetDashboard` concern

Extract figure computation. **Both dashboards must render byte-identically afterwards** — this task changes structure, not output.

**Critical:** CAPEX and OPEX use *different* conversion arithmetic and different settings shapes. CAPEX reads `capex_exchange_rates_<year>` → `capex_exchange_rates` → `exchange_rates` and **divides** (`amount / rate`, via `CapexHelper#convert_capex_currency`). OPEX reads `opex_exchange_rates[<year>]` and **multiplies** (`amount * rate`). The concern therefore takes a converter and must not unify the arithmetic — doing so would change one dashboard's numbers, which the spec forbids.

**Files:**
- Create: `app/controllers/concerns/budget_dashboard.rb`
- Modify: `app/controllers/capex_controller.rb:94-160`
- Modify: `app/controllers/opex_controller.rb:106-155`

**Interfaces:**
- Consumes: `CapexHelper#convert_capex_currency`, `CapexHelper#capex_missing_rate?`.
- Produces:

```ruby
budget_dashboard_figures(entries, currency:, convert:, missing_rate:)
# entries      – Array of Capex/Opex records (already scoped and preloaded)
# currency:    – String, the target currency
# convert:     – ->(amount, from_currency) { converted_amount }
# missing_rate:– ->(from_currency) { true|false }   (or nil when N/A)
# returns Hash with symbol keys:
#   :total_budget, :total_utilized, :total_remaining (Float, rounded 2)
#   :utilization_percentage (Float, rounded 2)
#   :currencies_mixed (Boolean)
#   :unconvertible_currencies (Array<String>)
#   :totals_unreliable (Boolean)
#   :over_budget (Boolean)
#   :severity (String: 'low'|'medium'|'high')
```

- [ ] **Step 1: Capture the pre-change baseline**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture t2_before 2>&1 | grep -v 'warning:'
```

- [ ] **Step 2: Write the concern**

Create `app/controllers/concerns/budget_dashboard.rb`:

```ruby
# Figure computation shared by the CAPEX and OPEX dashboards.
#
# These two surfaces are near-clones that drifted: six remediation passes
# landed on CAPEX and OPEX received a subset of each, so OPEX ended up with no
# currency-reliability model at all. Computing the figures in one place is what
# makes that structurally impossible rather than a thing to remember.
#
# Conversion is injected rather than implemented here on purpose. CAPEX and
# OPEX use different settings shapes AND opposite arithmetic (CAPEX divides by
# its rate, OPEX multiplies). Unifying them would change one dashboard's
# numbers, which is a finance decision, not a refactor.
module BudgetDashboard
  extend ActiveSupport::Concern

  # See the plan/spec for the full return contract.
  def budget_dashboard_figures(entries, currency:, convert:, missing_rate: nil)
    entries = entries.to_a

    total_budget   = entries.sum { |e| convert.call(e.total_amount    || 0, e.currency) }.round(2)
    total_utilized = entries.sum { |e| convert.call(e.utilized_amount || 0, e.currency) }.round(2)
    total_remaining = (total_budget - total_utilized).round(2)
    pct = total_budget > 0 ? ((total_utilized / total_budget) * 100).round(2) : 0

    currencies = entries.map { |e| e.currency.presence }.compact.uniq
    currencies_mixed = currencies.length > 1
    unconvertible = missing_rate ? currencies.select { |c| missing_rate.call(c) } : []

    # Two ways a total can lie: it added unlike units, or a currency was passed
    # through unconverted because no rate exists.
    totals_unreliable = (currencies_mixed && missing_rate.nil?) || unconvertible.any?

    # Severity is a conclusion. A conclusion drawn from a sum of unlike units
    # is a false alarm, so it is suppressed rather than shown in red.
    over_budget = !totals_unreliable && total_remaining < 0

    {
      total_budget: total_budget,
      total_utilized: total_utilized,
      total_remaining: total_remaining,
      utilization_percentage: pct,
      currencies_mixed: currencies_mixed,
      unconvertible_currencies: unconvertible,
      totals_unreliable: totals_unreliable,
      over_budget: over_budget,
      severity: over_budget ? 'high' : (pct >= 80 ? 'medium' : 'low')
    }
  end
end
```

- [ ] **Step 3: Confirm the concern autoloads**

The plugin has no `app/controllers/concerns/` precedent. Verify before wiring anything:

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  'puts BudgetDashboard.instance_methods(false).inspect' 2>&1 | grep -v 'warning:'
```

Expected: `[:budget_dashboard_figures]`.

If this raises `NameError`, add `require_dependency 'budget_dashboard'` inside the `Rails.application.config.to_prepare` block in `init.rb` (alongside the existing `require_dependency` calls) and re-run.

- [ ] **Step 4: Wire CAPEX to the concern**

In `app/controllers/capex_controller.rb`, add `include BudgetDashboard` under the class declaration. Replace lines 110-152 (from `if @use_exchange_rates` through the `@totals_unreliable` assignment) with:

```ruby
    figures = budget_dashboard_figures(
      capex_for_year,
      currency: @default_currency,
      convert: ->(amount, from) {
        @use_exchange_rates ? helpers.convert_capex_currency(amount, from, @default_currency, @current_year) : amount
      },
      missing_rate: (@use_exchange_rates ? ->(cur) { helpers.capex_missing_rate?(cur, @default_currency, @current_year) } : nil)
    )
    @total_budget            = figures[:total_budget]
    @total_utilized          = figures[:total_utilized]
    @total_remaining         = figures[:total_remaining]
    @utilization_percentage  = figures[:utilization_percentage]
    @currencies_mixed        = figures[:currencies_mixed]
    @unconvertible_currencies = figures[:unconvertible_currencies]
    @totals_unreliable       = figures[:totals_unreliable]
    @budget_over             = figures[:over_budget]
    @budget_severity         = figures[:severity]
```

- [ ] **Step 5: Verify CAPEX output is unchanged**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture t2_capex 2>&1 | grep -v 'warning:'
RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb compare t2_before t2_capex 2>&1 | grep -v 'warning:'
```

Expected: `same capex_data.html`, `same capex_empty.html`. **Any CAPEX diff is a defect — fix it before proceeding.** OPEX fixtures must also be `same` (untouched so far).

Note: the view still computes `capex_over_budget`/`capex_severity` inline at `dashboard.html.erb:39-45`. Leave that for now; Task 3 switches the view to `@budget_over`/`@budget_severity`. Keeping both in this task is what makes the byte-identical check meaningful.

- [ ] **Step 6: Wire OPEX to the concern**

In `app/controllers/opex_controller.rb`, add `include BudgetDashboard`. Replace lines 128-151 (the `if exchange_rates_settings[...]` block through `@utilization_percentage`) with:

```ruby
      opex_rates = (Setting.plugin_redmine_purchase_requests || {})
                     .dig('opex_exchange_rates', @current_year.to_s)
      @use_exchange_rates = opex_rates.present?

      figures = budget_dashboard_figures(
        @opex_entries,
        currency: @default_currency,
        # OPEX multiplies by its rate; CAPEX divides by its own. Preserved
        # exactly — reconciling the two conventions is a separate decision.
        convert: ->(amount, from) {
          @use_exchange_rates ? (amount * ((opex_rates || {})[from] || 1)) : amount
        },
        missing_rate: (@use_exchange_rates ? ->(cur) { !(opex_rates || {}).key?(cur) } : nil)
      )
      @total_budget           = figures[:total_budget]
      @total_utilized         = figures[:total_utilized]
      @total_remaining        = figures[:total_remaining]
      @utilization_percentage = figures[:utilization_percentage]
      @currencies_mixed        = figures[:currencies_mixed]
      @unconvertible_currencies = figures[:unconvertible_currencies]
      @totals_unreliable      = figures[:totals_unreliable]
      @budget_over            = figures[:over_budget]
      @budget_severity        = figures[:severity]
```

- [ ] **Step 7: Verify OPEX output is unchanged**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture t2_after 2>&1 | grep -v 'warning:'
RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb compare t2_before t2_after 2>&1 | grep -v 'warning:'
```

Expected: `ALL IDENTICAL`.

OPEX now *computes* `@totals_unreliable` but its view does not read it yet, so output is unchanged. That is intentional: the behaviour lands in Task 4.

- [ ] **Step 8: Syntax, restart, audit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
ruby -c app/controllers/concerns/budget_dashboard.rb
ruby -c app/controllers/capex_controller.rb
ruby -c app/controllers/opex_controller.rb
cd /opt/redmine && touch tmp/restart.txt && sleep 4 && \
  curl -s -o /dev/null -w "app HTTP %{http_code}\n" --max-time 30 http://172.17.86.242/
```

Then run the Task 1 Step 6 line-ending audit.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/concerns/budget_dashboard.rb app/controllers/capex_controller.rb app/controllers/opex_controller.rb
git commit -m "refactor: compute budget dashboard figures in one shared concern

CAPEX and OPEX each computed their own totals, which is how OPEX ended up
with no currency-reliability model. Both now call budget_dashboard_figures.

Conversion is injected, not unified: CAPEX divides by a rate from
capex_exchange_rates_<year>, OPEX multiplies by one from
opex_exchange_rates[<year>]. Reconciling those conventions is a finance
decision, not a refactor, so each keeps its own arithmetic.

Verified output-identical on all four fixtures via the HTML-diff harness."
```

---

### Task 3: Shared shell, rendered by CAPEX

Move CAPEX's markup into `shared/_budget_dashboard.html.erb` plus two CAPEX sub-partials. **CAPEX must still render byte-identically.**

**Files:**
- Create: `app/views/shared/_budget_dashboard.html.erb`
- Create: `app/views/capex/_grouping.html.erb`
- Create: `app/views/capex/_entries_table.html.erb`
- Modify: `app/views/capex/dashboard.html.erb`

**Interfaces:**
- Consumes: the ivars set in Task 2 (`@budget_over`, `@budget_severity`, `@totals_unreliable`, `@unconvertible_currencies`, `@total_*`, `@utilization_percentage`, `@currency_breakdown`, `@quarterly_data`, `@current_year`, `@default_currency`).
- Produces: the shell partial, rendered as

```erb
<%= render 'shared/budget_dashboard',
      grouping_partial: 'capex/grouping',
      entries_partial:  'capex/entries_table',
      labels: {
        title:        l(:label_capex_dashboard),
        by_group:     l(:label_budget_by_tpc_code),
        by_currency:  l(:label_capex_by_currency),
        entries:      l(:label_capex_entries),
        new_entry:    l(:label_new_capex_entry),
        back_to_list: l(:label_back_to_capex_list)
      },
      new_entry_path: new_project_capex_path(@project),
      list_path:      project_capex_index_path(@project),
      currency_symbol: capex_currency_symbol(@default_currency) %>
```

- [ ] **Step 1: Capture baseline**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture t3_before 2>&1 | grep -v 'warning:'
```

- [ ] **Step 2: Extract the grouping section verbatim**

Cut the TPC grouping block from `app/views/capex/dashboard.html.erb` (the `<!-- TPC Code Grouping -->` section, which begins at line 297) into `app/views/capex/_grouping.html.erb` **without editing a character of it**. It reads `@tpc_grouping`, which stays an ivar.

- [ ] **Step 3: Extract the entries table verbatim**

Cut the `<!-- CAPEX Entries Details Table -->` section (which begins at line 357) into `app/views/capex/_entries_table.html.erb`, unedited. It reads `@capex_entries`.

- [ ] **Step 4: Verify the two extractions changed nothing**

Render them from `capex/dashboard.html.erb` in place:

```erb
<%= render 'capex/grouping' %>
<%= render 'capex/entries_table' %>
```

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture t3_extract 2>&1 | grep -v 'warning:'
RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb compare t3_before t3_extract 2>&1 | grep -v 'warning:'
```

Expected: `ALL IDENTICAL`. Whitespace differences count as a diff — if the only change is a trailing newline introduced by the extraction, fix the partial rather than accepting the diff, because Task 4 relies on this check being strict.

- [ ] **Step 5: Commit the extraction**

```bash
git add app/views/capex/_grouping.html.erb app/views/capex/_entries_table.html.erb app/views/capex/dashboard.html.erb
git commit -m "refactor: extract CAPEX grouping and entries table into partials

Verbatim extraction, verified output-identical on all fixtures."
```

- [ ] **Step 6: Move the remaining CAPEX markup into the shared shell**

Move everything left in `app/views/capex/dashboard.html.erb` (banner, tiles, donut card, quarterly card, currency card) into `app/views/shared/_budget_dashboard.html.erb`, replacing the model-specific pieces with the locals from the Interfaces block above:

- literal `l(:label_capex_dashboard)` → `labels[:title]`
- `l(:label_budget_by_tpc_code)` → `labels[:by_group]`
- `l(:label_capex_by_currency)` → `labels[:by_currency]`
- `l(:label_capex_entries)` → `labels[:entries]`
- `capex_currency_symbol(@default_currency)` → `currency_symbol`
- `Capex.new(currency: X).currency_symbol` → `currency_symbol_for(X)` — add this as a local too: `currency_symbol_for: ->(cur) { Capex.new(currency: cur).currency_symbol }`
- the inline `capex_over_budget` / `capex_severity` computation at the top → `@budget_over` / `@budget_severity` from Task 2
- `new_project_capex_path` / `project_capex_index_path` → `new_entry_path` / `list_path`
- `<%= render 'capex/grouping' %>` → `<%= render grouping_partial %>`
- `<%= render 'capex/entries_table' %>` → `<%= render entries_partial %>`

`app/views/capex/dashboard.html.erb` becomes only its `content_for :header_tags`, `html_title`, the contextual button bar, the filter render, and the single `render 'shared/budget_dashboard', ...` call from the Interfaces block.

- [ ] **Step 7: Verify CAPEX is still byte-identical**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture t3_after 2>&1 | grep -v 'warning:'
RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb compare t3_before t3_after 2>&1 | grep -v 'warning:'
```

Expected: `ALL IDENTICAL`. A diff here means a local was substituted wrongly — read the diff, do not adjust the expectation.

- [ ] **Step 8: Standing checks**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner '
%w[capex/dashboard opex/dashboard shared/_budget_dashboard capex/_grouping capex/_entries_table].each do |rel|
  p = "plugins/redmine_purchase_requests/app/views/#{rel}.html.erb"
  next unless File.exist?(p)
  begin
    h = ActionView::Template::Handlers::ERB.new
    RubyVM::InstructionSequence.compile(h.call(Struct.new(:identifier,:type).new(p,nil), File.read(p)))
    puts "  ERB OK   #{rel}"
  rescue SyntaxError => e
    puts "  ERB FAIL #{rel}: #{e.message[0,120]}"
  end
end' 2>&1 | grep -v 'warning:'
cd /opt/redmine/plugins/redmine_purchase_requests && \
  node /home/fienan/.claude/plugins/cache/impeccable/impeccable/4.1.1/skills/impeccable/scripts/detect.mjs --json app/views/shared/_budget_dashboard.html.erb
```

Then the Task 1 Step 6 line-ending audit, `touch /opt/redmine/tmp/restart.txt`, and a 200 check.

- [ ] **Step 9: Commit**

```bash
git add app/views/shared/_budget_dashboard.html.erb app/views/capex/dashboard.html.erb
git commit -m "refactor: render the CAPEX dashboard from a shared shell partial

The shell owns the banner, tiles, donut, quarterly bars and currency
breakdown; the grouping section and entries table stay CAPEX-specific
partials it renders. Verified output-identical on all fixtures."
```

---

### Task 4: OPEX renders the shell

The only task whose output *should* change. OPEX gains, in one step, everything CAPEX has: the reliability banner and gate, over-budget framing on tile/legend/table, severity colours, the arc-path donut with token-resolved colours and the ≥100% branch, and risk-ordered grouping.

**Files:**
- Create: `app/views/opex/_grouping.html.erb`
- Create: `app/views/opex/_entries_table.html.erb`
- Modify: `app/views/opex/dashboard.html.erb`
- Modify: `app/controllers/opex_controller.rb` (sort `@category_grouping` by utilization desc)

**Interfaces:**
- Consumes: the shell from Task 3 and the concern from Task 2.
- Produces: nothing new.

- [ ] **Step 1: Capture baseline**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture t4_before 2>&1 | grep -v 'warning:'
```

- [ ] **Step 2: Create the OPEX grouping partial**

Copy `app/views/capex/_grouping.html.erb` to `app/views/opex/_grouping.html.erb` and change only the data source and label: `@tpc_grouping` → `@category_grouping`, and the per-card heading from the TPC number to the category name. Keep the severity classes, clamped widths, mixed-currency badge and risk ordering exactly as CAPEX has them.

- [ ] **Step 3: Create the OPEX entries table partial**

Copy `app/views/capex/_entries_table.html.erb` to `app/views/opex/_entries_table.html.erb`. Change `@capex_entries` → `@opex_entries`, the `TPC Code` column to `l(:label_opex_code)` reading `opex.opex_code`, add the category column, and swap the row action paths to the OPEX routes (`project_opex_path`, `edit_project_opex_path`) with `l(:label_view_opex)` / `l(:label_edit_opex)` / `l(:label_delete_opex)`.

- [ ] **Step 4: Sort OPEX grouping by risk**

In `app/controllers/opex_controller.rb`, add the sort after the loop that
populates `@category_grouping` **in the `dashboard` action** — the hash is
assigned at two places, line 176 (`dashboard`) and line 262 (`dashboard_data`).
Only the `dashboard` one feeds this view. Add:

```ruby
    # Alphabetical is merely what group_by returned. This section answers
    # "which categories are at risk", so the most utilized lead.
    @category_grouping = @category_grouping.sort_by { |_k, d| -d[:utilization_percentage].to_f }.to_h
```

Confirm placement is *after* the populating loop, not before — inserting it
earlier makes it a silent no-op on an empty hash and then raises on `nil`
when the loop later assigns. This exact mistake was made once already during
the CAPEX equivalent, so verify by printing the surrounding lines before and
after editing.

- [ ] **Step 5: Point the OPEX view at the shell**

Replace the body of `app/views/opex/dashboard.html.erb` with the same wrapper shape as CAPEX:

```erb
<%= render 'shared/budget_dashboard',
      grouping_partial: 'opex/grouping',
      entries_partial:  'opex/entries_table',
      labels: {
        title:        l(:label_opex_dashboard),
        by_group:     l(:label_budget_by_category),
        by_currency:  l(:label_opex_by_currency),
        entries:      l(:label_opex_entries),
        new_entry:    l(:label_new_opex_entry),
        back_to_list: l(:label_back_to_opex_list)
      },
      new_entry_path: new_project_opex_path(@project),
      list_path:      project_opex_index_path(@project),
      currency_symbol: currency_symbol(@default_currency),
      currency_symbol_for: ->(cur) { Opex.new(currency: cur).currency_symbol } %>
```

Delete OPEX's old inline `<script>` block entirely — the shell supplies the chart code, and OPEX's stroke-dash donut is the implementation that never rendered.

- [ ] **Step 6: Verify CAPEX unchanged and read the OPEX diff**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture t4_after 2>&1 | grep -v 'warning:'
RAILS_ENV=production bundle exec rails runner \
  plugins/redmine_purchase_requests/script/dashboard_snapshot.rb compare t4_before t4_after 2>&1 | grep -v 'warning:'
```

Expected: `same capex_data.html`, `same capex_empty.html`; `DIFF opex_data.html`, likely `DIFF opex_empty.html`.

**Read the OPEX diff line by line.** Every changed line must be explainable as one of: reliability banner added, over-budget framing, severity class on a meter, donut markup swapped, grouping reordered, a string now localised. Anything else — a lost column, a changed number, a dropped section — is a defect. **Show this diff in the report rather than summarising it.**

- [ ] **Step 7: Confirm the numbers did not move**

```bash
cd /opt/redmine && RAILS_ENV=production bundle exec rails runner '
Opex.order(:id).each { |o| puts "  opex ##{o.id}: budget=#{o.total_amount} utilized=#{o.utilized_amount.round(2)} remaining=#{o.remaining_amount.round(2)} util=#{o.utilization_percentage}%" }' 2>&1 | grep -v 'warning:'
```

Compare against the same command run before Task 4. Figures must be identical — this task changes presentation, not arithmetic.

- [ ] **Step 8: Standing checks**

ERB compile on `opex/dashboard`, `opex/_grouping`, `opex/_entries_table`, `shared/_budget_dashboard`; `ruby -c` on `opex_controller.rb`; `node --check` on the shared asset; detector on both dashboards and the shell; the `pr-*--modifier` audit; the line-ending audit; `rake assets:precompile` (the shell may move JS), restart, 200 check.

- [ ] **Step 9: Commit**

```bash
git add app/views/opex/_grouping.html.erb app/views/opex/_entries_table.html.erb app/views/opex/dashboard.html.erb app/controllers/opex_controller.rb
git commit -m "refactor: render the OPEX dashboard from the shared shell

OPEX inherits in one step what six passes had given CAPEX and not it: the
currency-reliability banner and gate, over-budget framing on tile, legend and
table, the severity vocabulary, the arc-path donut with token-resolved
colours and a >=100% branch, and risk-ordered grouping.

Its stroke-dash donut is deleted rather than ported — it set stroke as an SVG
presentation attribute to var(--pr-success), which is never substituted, so
it had never rendered.

CAPEX verified byte-identical; the OPEX diff was reviewed line by line."
```

---

## Self-Review

**Spec coverage.** Concern → Task 2. Shared shell → Task 3. Per-model sections → Tasks 3 and 4. Donut consolidation → Task 4 Step 5. Three-step rollout with OPEX last → task order. HTML-diff harness and fixtures → Task 1. Line-ending and standing audits → Global Constraints plus each task's penultimate step. Out-of-scope items are not planned, as intended.

**Deviation from the spec, deliberate:** the spec's fixture table lists seven (F1–F7); the harness implements four (`capex_data`, `capex_empty`, `opex_data`, `opex_empty`). The remaining three — exactly-100%, mixed-currency-rates-off, missing-rate — cannot be produced from current data without creating records, and the spec forbids changing what the dashboards show. Task 2's concern covers those branches in pure logic and they were exercised directly during the preceding critique work. **This is a real gap in coverage and is called out rather than papered over:** if the reviewer wants them, Task 1 must gain a fixture-seeding step that creates and rolls back throwaway records in a transaction.

**Placeholder scan.** No TBD/TODO. Every code step carries literal code. Extraction steps name the exact sections and their current line ranges.

**Type consistency.** `budget_dashboard_figures` returns the same nine symbol keys in Task 2 and is consumed with those names in Tasks 2–4. `@budget_over` / `@budget_severity` are introduced in Task 2 Step 4 and consumed in Task 3 Step 6. `grouping_partial` / `entries_partial` / `labels` / `currency_symbol` / `currency_symbol_for` / `new_entry_path` / `list_path` are defined in Task 3's Interfaces block and used identically in Task 4 Step 5.
