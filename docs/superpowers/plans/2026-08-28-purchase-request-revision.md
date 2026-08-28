# Purchase Request Revision and Cancellation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an in-flight purchase request be cancelled or replaced by a revision, keeping the superseded record intact, and stop cancelled and superseded work from consuming CAPEX and OPEX budget.

**Architecture:** A `lifecycle` column (`active` / `cancelled` / `superseded`) sits beside `status`, which keeps meaning progress. Revising creates a second `PurchaseRequest` linked back through `revision_of_id`, whose unique index makes double-revision impossible. Every figure representing committed money routes through one `PurchaseRequest.committed_sum` helper, so the budget rule is written once rather than thirty times.

**Tech Stack:** Redmine 5.1.9, Rails 6.1.7, Ruby 3.1.4, MySQL, Minitest (`ActiveSupport::TestCase`).

**Spec:** `docs/superpowers/specs/2026-08-28-purchase-request-revision-design.md`

## Global Constraints

- Plugin root is `/opt/redmine/plugins/redmine_purchase_requests`; Redmine root is `/opt/redmine`.
- Migrations are numbered sequentially without zero-padding beyond three digits. The last is `040_drop_tpc_codes_department_string.rb`, so the next is `041`.
- Tests require the Redmine helper by relative path: `require File.expand_path('../../../../../test/test_helper', __FILE__)`.
- Run a single test file with:
  `cd /opt/redmine && RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/<file>.rb`
- Two existing rake gates must stay green after every task:
  `bundle exec rake redmine_purchase_requests:check_templates`
  `bundle exec rake redmine_purchase_requests:ratchet`
- The ratchet fails when a frontend-debt count grows. New markup must use design tokens (`var(--pr-*)`), must not add inline `style=` attributes, and every `<th>` must carry `scope`.
- `lifecycle` values are the strings `'active'`, `'cancelled'`, `'superseded'`. No symbols, no enum integers.
- Never filter a preloaded association with a scoped `where` — see Task 3.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `db/migrate/041_add_lifecycle_to_purchase_requests.rb` | six columns, unique index, foreign keys |
| `app/models/purchase_request.rb` | lifecycle constants, scopes, predicates, `committed_sum`, revise/cancel behaviour |
| `app/models/purchase_request_status.rb` | the `foreign_key` fix |
| `app/models/capex.rb`, `app/models/opex.rb` | `utilized_amount` respects lifecycle |
| `app/controllers/purchase_requests_controller.rb` | `revise`, `cancel`, `uncancel` actions; money sums |
| `app/controllers/reports_controller.rb` | 24 money sums routed through the helper |
| `app/views/purchase_requests/show.html.erb` | lifecycle banner, revision chain, action buttons |
| `app/views/purchase_requests/_lifecycle_banner.html.erb` | the banner, extracted so show.html.erb does not grow |
| `app/views/purchase_requests/cancel.html.erb` | cancellation form (reason required) |
| `app/views/capex/show.html.erb`, `app/views/opex/show.html.erb` | non-counting rows annotated (note: different instance variables) |
| `config/routes.rb` | member routes for the three actions |
| `init.rb` | two permissions |
| `config/locales/en.yml` | new labels |
| `test/unit/purchase_request_lifecycle_test.rb` | transitions, guards, atomicity |
| `test/unit/budget_rollback_test.rb` | the money assertions |

---

## Task 0: Unblock the test environment

Nothing in this plan can be verified until the test environment boots. It currently does not.

**Files:**
- Install: `/opt/redmine/plugins/redmine_base_rspec`

**Interfaces:**
- Produces: a bootable `RAILS_ENV=test`, which every later task depends on.

- [ ] **Step 1: Confirm the failure, so the fix is verifiable**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -e 'require "./config/environment"' 2>&1 | grep -v '^\s*from' | head -3
```
Expected: `redmine_customize_core_fields plugin requires the redmine_base_rspec plugin (Redmine::PluginRequirementError)`

- [ ] **Step 2: Install the missing plugin**

```bash
cd /opt/redmine/plugins
git clone https://github.com/jbbarth/redmine_base_rspec.git
```

- [ ] **Step 3: Verify the test environment now boots**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -e 'require "./config/environment"; puts "BOOTED"'
```
Expected: `BOOTED`

- [ ] **Step 4: Prepare the test database**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec rake db:drop db:create db:migrate redmine:plugins:migrate
```
Expected: completes without error. This touches `redmine_test` only — confirm with
`grep -A3 '^test:' config/database.yml` that the database is `redmine_test`, not `redmine`, before running.

- [ ] **Step 5: Record the baseline**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec rake redmine:plugins:test NAME=redmine_purchase_requests 2>&1 | tail -20
```
These six files have never run here, so failures are possible. Record the result in the commit message. Do **not** fix pre-existing failures in this task — that is separate work. The baseline is what later tasks compare against.

- [ ] **Step 6: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git commit --allow-empty -m "chore(test): record the test-suite baseline

redmine_customize_core_fields declares a test-only dependency on
redmine_base_rspec, which was not installed, so RAILS_ENV=test failed during
initialisation and this plugin's six test files had never run.

redmine_base_rspec is now installed. Baseline: <paste the tail output here>."
```

---

## Task 1: Lifecycle schema and model vocabulary

**Files:**
- Create: `db/migrate/041_add_lifecycle_to_purchase_requests.rb`
- Modify: `app/models/purchase_request.rb`
- Modify: `app/models/purchase_request_status.rb`
- Test: `test/unit/purchase_request_lifecycle_test.rb`

**Interfaces:**
- Produces: `PurchaseRequest::LIFECYCLES`, `#active?`, `#cancelled?`, `#superseded?`, `#counts_toward_budget?`, `.budgeted`, `#revision_of`, `#superseded_by`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/purchase_request_lifecycle_test.rb`:

```ruby
require File.expand_path('../../../../../test/test_helper', __FILE__)

class PurchaseRequestLifecycleTest < ActiveSupport::TestCase
  def build_request(attrs = {})
    PurchaseRequest.new({
      title: 'A valid purchase request title',
      description: 'A description long enough to pass validation.',
      priority: 'normal',
      status_id: PurchaseRequestStatus.default&.id,
      estimated_price: 100
    }.merge(attrs))
  end

  test 'a new request is active' do
    assert_equal 'active', build_request.lifecycle
    assert build_request.active?
    assert build_request.counts_toward_budget?
  end

  test 'cancelled and superseded do not count toward budget' do
    assert_not build_request(lifecycle: 'cancelled').counts_toward_budget?
    assert_not build_request(lifecycle: 'superseded').counts_toward_budget?
  end

  test 'lifecycle is restricted to the three known values' do
    request = build_request(lifecycle: 'nonsense')
    assert_not request.valid?
    assert_includes request.errors.attribute_names, :lifecycle
  end

  test 'the budgeted scope selects only active requests' do
    assert_equal ['active'], PurchaseRequest.budgeted.where_values_hash['lifecycle'].then { |v| Array(v) }
  end

  test 'a status can list its purchase requests' do
    # Regression: has_many omitted foreign_key, so this queried a column
    # named purchase_request_status_id, which does not exist.
    assert_nothing_raised { PurchaseRequestStatus.first&.purchase_requests&.count }
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/purchase_request_lifecycle_test.rb
```
Expected: FAIL — `undefined method 'lifecycle'`

- [ ] **Step 3: Write the migration**

Create `db/migrate/041_add_lifecycle_to_purchase_requests.rb`:

```ruby
class AddLifecycleToPurchaseRequests < ActiveRecord::Migration[5.2]
  # Guarded throughout: this plugin's migrations have been re-run against
  # partially-migrated databases before, and a bare add_column would abort.
  def up
    unless column_exists?(:purchase_requests, :lifecycle)
      add_column :purchase_requests, :lifecycle, :string, null: false, default: 'active'
      add_index :purchase_requests, :lifecycle
    end

    unless column_exists?(:purchase_requests, :revision_of_id)
      add_column :purchase_requests, :revision_of_id, :integer, null: true
      # Unique, not merely indexed: it is what makes it impossible to revise
      # one request twice and end up with two children both consuming budget
      # against a single intent. MySQL permits repeated NULLs, so unrevised
      # requests are unaffected.
      add_index :purchase_requests, :revision_of_id, unique: true
    end

    unless column_exists?(:purchase_requests, :revision_number)
      add_column :purchase_requests, :revision_number, :integer, null: false, default: 1
    end

    unless column_exists?(:purchase_requests, :cancelled_at)
      add_column :purchase_requests, :cancelled_at, :datetime, null: true
      add_column :purchase_requests, :cancelled_by_id, :integer, null: true
      add_column :purchase_requests, :cancellation_reason, :text, null: true
      add_index :purchase_requests, :cancelled_by_id
    end
  end

  def down
    %i[lifecycle revision_of_id revision_number
       cancelled_at cancelled_by_id cancellation_reason].each do |col|
      remove_column :purchase_requests, col if column_exists?(:purchase_requests, col)
    end
  end
end
```

- [ ] **Step 4: Run the migration against the test database**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests
```
Expected: `041 AddLifecycleToPurchaseRequests: migrated`

- [ ] **Step 5: Add the model vocabulary**

In `app/models/purchase_request.rb`, after the existing `belongs_to` block:

```ruby
  LIFECYCLES = %w[active cancelled superseded].freeze

  belongs_to :revision_of, class_name: 'PurchaseRequest', optional: true
  belongs_to :cancelled_by, class_name: 'User', optional: true
  has_one :superseded_by, class_name: 'PurchaseRequest', foreign_key: 'revision_of_id'

  validates :lifecycle, inclusion: { in: LIFECYCLES }

  # Only active requests represent money anyone still intends to spend.
  scope :budgeted, -> { where(lifecycle: 'active') }

  def active?      = lifecycle == 'active'
  def cancelled?   = lifecycle == 'cancelled'
  def superseded?  = lifecycle == 'superseded'

  def counts_toward_budget?
    active?
  end
```

- [ ] **Step 6: Fix the status association**

In `app/models/purchase_request_status.rb`, replace line 2:

```ruby
  # The column is status_id, not the purchase_request_status_id Rails would
  # infer, so every call to this association raised until the key was named.
  has_many :purchase_requests, foreign_key: 'status_id'
```

- [ ] **Step 7: Run the tests and watch them pass**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/purchase_request_lifecycle_test.rb
```
Expected: 5 runs, 0 failures, 0 errors

- [ ] **Step 8: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add db/migrate/041_add_lifecycle_to_purchase_requests.rb app/models/purchase_request.rb app/models/purchase_request_status.rb test/unit/purchase_request_lifecycle_test.rb
git commit -m "feat(lifecycle): add lifecycle, revision links and cancellation columns

lifecycle sits beside status: status keeps meaning how far a request got,
lifecycle whether it still counts. Defaults make the migration inert -- every
existing request becomes active, so no figure changes on deploy.

revision_of_id is uniquely indexed. That is what makes revising one request
twice impossible, which would otherwise produce two active children consuming
budget against a single intent.

Also fixes PurchaseRequestStatus#purchase_requests, which omitted
foreign_key: 'status_id' and so queried a column that does not exist."
```

---

## Task 2: The budget rule, and CAPEX/OPEX rollback

This is requirement 3. After this task, cancelling a request would free its budget — though nothing can cancel one yet, so the change is still inert.

**Files:**
- Modify: `app/models/purchase_request.rb`
- Modify: `app/models/capex.rb:64-76`
- Modify: `app/models/opex.rb:68-79`
- Test: `test/unit/budget_rollback_test.rb`

**Interfaces:**
- Consumes: `#counts_toward_budget?`, `.budgeted` from Task 1.
- Produces: `PurchaseRequest.committed_sum(scope = all)` returning a `BigDecimal`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/budget_rollback_test.rb`:

```ruby
require File.expand_path('../../../../../test/test_helper', __FILE__)

class BudgetRollbackTest < ActiveSupport::TestCase
  fixtures :projects, :users

  def setup
    @project = Project.first
    @status  = PurchaseRequestStatus.default || PurchaseRequestStatus.create!(
      name: 'Test status', position: 99, color: '#3a5bbf'
    )
    @capex = Capex.create!(
      project: @project, tpc_code: 'TPC-TEST', description: 'Budget under test',
      total_amount: 1000, currency: 'USD', year: Date.current.year
    )
  end

  def add_request(price, lifecycle: 'active')
    PurchaseRequest.create!(
      project: @project, user: User.first, status_id: @status.id,
      title: "Request for #{price}", description: 'Long enough description.',
      priority: 'normal', estimated_price: price, currency: 'USD',
      capex_id: @capex.id, lifecycle: lifecycle
    )
  end

  test 'cancelling a request returns exactly its amount to the budget' do
    add_request(100)
    add_request(250)
    doomed = add_request(400)

    assert_equal 750, @capex.reload.utilized_amount
    assert_equal 250, @capex.remaining_amount

    doomed.update!(lifecycle: 'cancelled')

    assert_equal 350, @capex.reload.utilized_amount,
                 'utilized_amount must drop by exactly the cancelled amount'
    assert_equal 650, @capex.remaining_amount,
                 'remaining_amount must rise to match'
  end

  test 'a superseded request stops counting' do
    add_request(100)
    replaced = add_request(500)
    replaced.update!(lifecycle: 'superseded')

    assert_equal 100, @capex.reload.utilized_amount
  end

  test 'completed requests still count' do
    closed = PurchaseRequestStatus.create!(
      name: 'Closed for test', position: 98, color: '#2f9e44', is_closed: true
    )
    add_request(300).update!(status_id: closed.id)

    assert_equal 300, @capex.reload.utilized_amount,
                 'money already committed does not stop counting when the request closes'
  end

  test 'committed_sum excludes non-active requests' do
    add_request(100)
    add_request(200, lifecycle: 'cancelled')

    assert_equal 100, PurchaseRequest.committed_sum(PurchaseRequest.where(capex_id: @capex.id))
  end

  test 'summing a budget does not issue a query per request' do
    5.times { |i| add_request(10 * (i + 1)) }
    capex = Capex.includes(:purchase_requests).find(@capex.id)

    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      capex.utilized_amount
    end

    assert_equal 0, queries,
                 'utilized_amount must filter the preloaded association in Ruby; ' \
                 'a scoped where here reintroduces the N+1 that includes() removed'
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/budget_rollback_test.rb
```
Expected: FAIL — `utilized_amount` returns 750 after cancelling, and `committed_sum` is undefined.

- [ ] **Step 3: Add the helper**

In `app/models/purchase_request.rb`, below the `budgeted` scope:

```ruby
  # The single statement of "money we are still committed to". Every figure
  # representing committed spend calls this rather than repeating the filter,
  # so a site missed during a sweep is a visible leftover of the old pattern
  # rather than an invisible wrong number.
  #
  # Use this wherever the scope is a plain relation. Where an association has
  # been preloaded -- Capex and Opex -- filter in Ruby instead; see below.
  def self.committed_sum(scope = all)
    scope.budgeted.where.not(estimated_price: nil).sum(:estimated_price)
  end
```

- [ ] **Step 4: Teach CAPEX and OPEX the rule**

In `app/models/capex.rb`, replace line 71:

```ruby
    # Filtered in Ruby, not with a scoped where. The dashboard controller
    # preloads this association with includes(:purchase_requests); a scoped
    # where issues a fresh query per record even when it is preloaded, which
    # is the N+1 that preload was added to remove. PurchaseRequest.committed_sum
    # is for plain relations, not for this.
    purchase_requests.reject { |r| r.estimated_price.nil? || !r.counts_toward_budget? }.sum do |request|
```

Make the identical change at `app/models/opex.rb:74`, keeping its existing
cross-reference comment above it.

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/budget_rollback_test.rb
```
Expected: 5 runs, 0 failures, 0 errors

- [ ] **Step 6: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add app/models/purchase_request.rb app/models/capex.rb app/models/opex.rb test/unit/budget_rollback_test.rb
git commit -m "feat(budget): stop cancelled and superseded requests consuming budget

Capex and Opex summed every linked request and consulted status not at all,
so an abandoned request held budget indefinitely. They now skip anything
whose lifecycle is not active.

The filter is applied in Ruby rather than as a scoped where, because the
dashboard preloads the association and a scoped where would reissue the query
per record -- the N+1 that preload exists to prevent. A test asserts the query
count stays at zero so that a later tidy-up cannot quietly undo it.

PurchaseRequest.committed_sum states the same rule once for plain relations,
ready for the report sweep."
```

---

## Task 3: Route the remaining 28 money sites through the helper

**Files:**
- Modify: `app/controllers/purchase_requests_controller.rb` lines 306, 313, 414, 440
- Modify: `app/controllers/reports_controller.rb` lines 279, 314, 315, 316, 317, 366, 371, 376, 392, 652, 759, 996, 1048, 1149, 1188, 1228, 1284, 1410, 1420, 2155, 2157, 2159, 2161, 2183

**Interfaces:**
- Consumes: `PurchaseRequest.committed_sum` from Task 2.

- [ ] **Step 1: Write the failing test**

Append to `test/unit/budget_rollback_test.rb`:

```ruby
  test 'no money sum bypasses the budget rule' do
    root = File.expand_path('../../..', __FILE__)
    offenders = []

    Dir[File.join(root, 'app', 'controllers', '*.rb')].each do |path|
      File.readlines(path).each_with_index do |line, i|
        next unless line.include?('sum(:estimated_price)')
        next if line.include?('committed_sum')
        offenders << "#{File.basename(path)}:#{i + 1}"
      end
    end

    assert_empty offenders,
                 "these sum money without the lifecycle filter:\n  #{offenders.join("\n  ")}"
  end
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/budget_rollback_test.rb -n /bypasses/
```
Expected: FAIL listing 28 offending lines.

- [ ] **Step 3: Sweep the sites**

Each site follows one of two shapes. Rewrite in place:

```ruby
# before
total_estimated_value = purchase_requests.where.not(estimated_price: nil).sum(:estimated_price)
# after
total_estimated_value = PurchaseRequest.committed_sum(purchase_requests)

# before (with the rescue this file uses in places)
capex_utilized = PurchaseRequest.where.not(capex_id: nil).where.not(estimated_price: nil).sum(:estimated_price) rescue 0
# after
capex_utilized = PurchaseRequest.committed_sum(PurchaseRequest.where.not(capex_id: nil)) rescue 0

# grouped sums keep their grouping; only the filter moves
# before
scope.where.not(estimated_price: nil).group(:currency).sum(:estimated_price)
# after
scope.budgeted.where.not(estimated_price: nil).group(:currency).sum(:estimated_price)
```

Grouped sums cannot use `committed_sum` (it returns a scalar), so they call
`.budgeted` directly. That is why the test greps for the raw pattern rather
than for the helper name.

- [ ] **Step 4: Run the test and watch it pass**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/budget_rollback_test.rb
```
Expected: 6 runs, 0 failures

- [ ] **Step 5: Confirm counts were left alone**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git diff | grep -E '^[-+].*\.count' | head
```
Expected: no output. Counts answer what was done; only money answers what is owed.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/purchase_requests_controller.rb app/controllers/reports_controller.rb test/unit/budget_rollback_test.rb
git commit -m "feat(budget): route every money sum through the lifecycle rule

28 further sites summed estimated_price without consulting lifecycle, so a
cancelled request would have vanished from the CAPEX and OPEX figures while
still inflating every report. They now call PurchaseRequest.committed_sum, or
.budgeted where the sum is grouped and the helper's scalar return will not do.

A test greps the controllers for the raw pattern, so a site added later
without the filter fails the suite rather than disagreeing quietly with the
dashboards.

Counts are untouched, per the spec: they answer what was done, not what is
owed."
```

---

## Task 4: Cancel and uncancel

**Files:**
- Modify: `app/models/purchase_request.rb`
- Modify: `app/controllers/purchase_requests_controller.rb`
- Create: `app/views/purchase_requests/cancel.html.erb`
- Modify: `config/routes.rb`, `init.rb`, `config/locales/en.yml`
- Test: `test/unit/purchase_request_lifecycle_test.rb`

**Interfaces:**
- Consumes: `#active?`, `#cancelled?` from Task 1.
- Produces: `#cancel!(user:, reason:)`, `#uncancel!`, `#cancellable?`, `#uncancellable?`.

- [ ] **Step 1: Write the failing test**

Append to `test/unit/purchase_request_lifecycle_test.rb`:

```ruby
  test 'cancelling records who, when and why' do
    request = create_persisted_request
    request.cancel!(user: User.first, reason: 'Supplier withdrew the quotation')

    assert request.cancelled?
    assert_equal 'Supplier withdrew the quotation', request.cancellation_reason
    assert_equal User.first, request.cancelled_by
    assert_not_nil request.cancelled_at
  end

  test 'cancelling leaves status alone' do
    request = create_persisted_request
    before = request.status_id
    request.cancel!(user: User.first, reason: 'No longer needed')

    assert_equal before, request.reload.status_id,
                 'status records how far it got and must survive cancellation'
  end

  test 'a reason is required' do
    request = create_persisted_request
    assert_raises(ArgumentError) { request.cancel!(user: User.first, reason: '  ') }
    assert request.reload.active?
  end

  test 'uncancelling restores an active request and clears the record' do
    request = create_persisted_request
    request.cancel!(user: User.first, reason: 'Mistake')
    request.uncancel!

    assert request.active?
    assert_nil request.cancelled_at
    assert_nil request.cancelled_by_id
    assert_nil request.cancellation_reason
  end

  test 'a superseded request cannot be cancelled' do
    request = create_persisted_request
    request.update!(lifecycle: 'superseded')
    assert_not request.cancellable?
    assert_raises(RuntimeError) { request.cancel!(user: User.first, reason: 'x') }
  end
```

Add this helper to the test class:

```ruby
  def create_persisted_request
    PurchaseRequest.create!(
      project: Project.first, user: User.first,
      status_id: PurchaseRequestStatus.default.id,
      title: 'A persisted purchase request', description: 'Long enough description.',
      priority: 'normal', estimated_price: 100, currency: 'USD'
    )
  end
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/purchase_request_lifecycle_test.rb
```
Expected: FAIL — `undefined method 'cancel!'`

- [ ] **Step 3: Implement the operations**

In `app/models/purchase_request.rb`:

```ruby
  def cancellable?
    active?
  end

  # Uncancelling is refused once something supersedes the request: the budget
  # it would reclaim already belongs to its successor.
  def uncancellable?
    cancelled? && superseded_by.nil?
  end

  def cancel!(user:, reason:)
    raise ArgumentError, 'a cancellation reason is required' if reason.to_s.strip.empty?
    raise "cannot cancel a #{lifecycle} request" unless cancellable?

    update!(lifecycle: 'cancelled', cancelled_by: user,
            cancelled_at: Time.current, cancellation_reason: reason.strip)
  end

  def uncancel!
    raise "cannot uncancel a #{lifecycle} request" unless uncancellable?

    update!(lifecycle: 'active', cancelled_by_id: nil,
            cancelled_at: nil, cancellation_reason: nil)
  end
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/purchase_request_lifecycle_test.rb
```
Expected: 10 runs, 0 failures

- [ ] **Step 5: Add the permission**

In `init.rb`, after line 24:

```ruby
    permission :cancel_purchase_requests, { purchase_requests: [:cancel, :uncancel] }
```

- [ ] **Step 6: Add the routes**

In `config/routes.rb`, inside the `resources :purchase_requests` member block:

```ruby
        get 'cancel'
        post 'cancel', action: 'perform_cancel'
        post 'uncancel'
```

- [ ] **Step 7: Add the controller actions**

In `app/controllers/purchase_requests_controller.rb`:

```ruby
  def cancel
    render_403 unless @purchase_request.cancellable?
  end

  def perform_cancel
    @purchase_request.cancel!(user: User.current, reason: params[:cancellation_reason])
    flash[:notice] = l(:notice_purchase_request_cancelled)
    redirect_to purchase_request_path(@purchase_request)
  rescue ArgumentError => e
    flash.now[:error] = e.message
    render :cancel
  end

  def uncancel
    @purchase_request.uncancel!
    flash[:notice] = l(:notice_purchase_request_uncancelled)
    redirect_to purchase_request_path(@purchase_request)
  end
```

Add `:cancel, :perform_cancel, :uncancel` to the existing
`before_action :find_purchase_request` list.

- [ ] **Step 8: Add the view and locale keys**

Create `app/views/purchase_requests/cancel.html.erb`:

```erb
<h2><%= l(:label_cancel_purchase_request) %></h2>

<%= form_tag cancel_purchase_request_path(@purchase_request), method: :post, class: 'pr-form' do %>
  <p class="pr-subhead"><%= l(:text_cancel_purchase_request_intro) %></p>

  <div class="pr-field">
    <label for="cancellation_reason"><%= l(:field_cancellation_reason) %> <span class="required">*</span></label>
    <%= text_area_tag :cancellation_reason, params[:cancellation_reason], rows: 4, required: true %>
  </div>

  <div class="pr-form-actions">
    <%= submit_tag l(:button_cancel_request), class: 'pr-button pr-button-danger', name: nil %>
    <%= link_to l(:button_back), purchase_request_path(@purchase_request), class: 'pr-button pr-button-cancel' %>
  </div>
<% end %>
```

Add to `config/locales/en.yml` under `en:`:

```yaml
  label_cancel_purchase_request: "Cancel purchase request"
  text_cancel_purchase_request_intro: "Cancelling releases this request's budget. It stays in the list with its history intact, and can be reinstated."
  field_cancellation_reason: "Reason for cancellation"
  button_cancel_request: "Cancel this request"
  button_reinstate_request: "Reinstate"
  notice_purchase_request_cancelled: "Purchase request cancelled and its budget released."
  notice_purchase_request_uncancelled: "Purchase request reinstated."
```

- [ ] **Step 9: Run both gates**

```bash
cd /opt/redmine
bundle exec rake redmine_purchase_requests:check_templates
bundle exec rake redmine_purchase_requests:ratchet
```
Expected: templates compile cleanly; nothing grew.

- [ ] **Step 10: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add -A
git commit -m "feat(lifecycle): cancel a purchase request, and reinstate it

Cancelling records who, when and why, and releases the budget. status is left
untouched, which is what preserves how far the request got before it stopped.

A reason is required: a budget-affecting action nobody can audit afterwards is
worse than no action. Reinstating is available because otherwise a mis-click
needs SQL to undo, and it is refused once a successor exists -- that budget
now belongs to the successor.

cancel_purchase_requests is its own permission, so releasing budget can be
withheld from people who may otherwise edit."
```

---

## Task 5: Revise

**Files:**
- Modify: `app/models/purchase_request.rb`
- Modify: `app/controllers/purchase_requests_controller.rb`, `config/routes.rb`, `init.rb`, `config/locales/en.yml`
- Test: `test/unit/purchase_request_lifecycle_test.rb`

**Interfaces:**
- Consumes: `#active?`, `#superseded_by` from Task 1.
- Produces: `#revisable?`, `#build_revision`, `#revise!(user:)` returning the persisted child.

- [ ] **Step 1: Write the failing test**

```ruby
  test 'revising creates a child and supersedes the parent' do
    parent = create_persisted_request
    child  = parent.revise!(user: User.first)

    assert child.persisted?
    assert child.active?
    assert_equal parent.id, child.revision_of_id
    assert_equal 2, child.revision_number
    assert parent.reload.superseded?
    assert_equal child, parent.superseded_by
  end

  test 'the revision copies the fields that carry forward' do
    parent = create_persisted_request
    parent.update!(currency: 'EUR', priority: 'high', notes: 'Original notes')
    child = parent.revise!(user: User.first)

    assert_equal parent.title, child.title
    assert_equal parent.currency, child.currency
    assert_equal parent.priority, child.priority
    assert_equal parent.notes, child.notes
    assert_equal parent.user_id, child.user_id, 'the request still belongs to whoever raised it'
  end

  test 'the revision starts at the default status and carries no issue' do
    parent = create_persisted_request
    other  = PurchaseRequestStatus.create!(name: 'Advanced', position: 97, color: '#df8709')
    parent.update!(status_id: other.id, issue_id: nil)
    child = parent.revise!(user: User.first)

    assert_equal PurchaseRequestStatus.default.id, child.status_id,
                 'a changed price must be approved again'
    assert_nil child.issue_id
  end

  test 'a request cannot be revised twice' do
    parent = create_persisted_request
    parent.revise!(user: User.first)
    parent.update_column(:lifecycle, 'active')  # force the guard to be the index

    assert_raises(ActiveRecord::RecordNotUnique) { parent.revise!(user: User.first) }
  end

  test 'revise is atomic' do
    parent = create_persisted_request
    PurchaseRequest.any_instance.stubs(:save!).raises(ActiveRecord::RecordInvalid.new(PurchaseRequest.new))

    assert_raises(ActiveRecord::RecordInvalid) { parent.revise!(user: User.first) }
    assert parent.reload.active?, 'a failed revision must leave the parent active'
  end
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/purchase_request_lifecycle_test.rb
```
Expected: FAIL — `undefined method 'revise!'`

- [ ] **Step 3: Implement**

```ruby
  COPIED_ON_REVISION = %w[
    title description project_id vendor_id vendor tpc_code_id
    capex_id opex_id category_id allocated_quarter allocated_amount
    estimated_price currency priority due_date product_url notes user_id
  ].freeze

  def revisable?
    active?
  end

  # Attachments are not copied: the superseded request keeps the quotation it
  # was approved against. issue_id is not copied: the issue belongs to the
  # version that raised it. status resets, because the price changed and needs
  # approving again.
  def build_revision
    child = PurchaseRequest.new(attributes.slice(*COPIED_ON_REVISION))
    child.revision_of_id  = id
    child.revision_number = revision_number + 1
    child.lifecycle       = 'active'
    child.status_id       = PurchaseRequestStatus.default&.id
    child
  end

  # One transaction: a parent superseded with no child would delete budget
  # silently. The unique index on revision_of_id is what stops a second
  # revision, so no check here can be raced past.
  def revise!(user:)
    raise "cannot revise a #{lifecycle} request" unless revisable?

    child = nil
    transaction do
      child = build_revision
      child.save!
      update!(lifecycle: 'superseded')
    end
    child
  end
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
cd /opt/redmine
RAILS_ENV=test bundle exec ruby -Itest plugins/redmine_purchase_requests/test/unit/purchase_request_lifecycle_test.rb
```
Expected: 15 runs, 0 failures

- [ ] **Step 5: Permission, route and action**

`init.rb`, after the cancel permission:

```ruby
    permission :revise_purchase_requests, { purchase_requests: [:revise] }
```

`config/routes.rb`, in the member block:

```ruby
        post 'revise'
```

Controller:

```ruby
  def revise
    child = @purchase_request.revise!(user: User.current)
    flash[:notice] = l(:notice_purchase_request_revised)
    redirect_to edit_purchase_request_path(child)
  end
```

Locale keys:

```yaml
  notice_purchase_request_revised: "Revision created. The previous version has been superseded and no longer counts toward budget."
  label_revision_of: "Revision of"
  label_superseded_by: "Superseded by"
  label_revision_number: "Version %{number}"
```

- [ ] **Step 6: Run the gates and commit**

```bash
cd /opt/redmine
bundle exec rake redmine_purchase_requests:check_templates && bundle exec rake redmine_purchase_requests:ratchet
cd plugins/redmine_purchase_requests && git add -A
git commit -m "feat(lifecycle): revise a request into a new version

Revising creates a second record linked back through revision_of_id and marks
the parent superseded, in one transaction -- a parent superseded with no child
would delete budget silently.

Attachments do not follow: the superseded request keeps the quotation it was
approved against, and the revision receives the new one. The issue link stays
with the version that raised it, and status resets to default because a
changed price needs approving again.

Revising twice is prevented by the unique index rather than a controller
check, so it cannot be raced."
```

---

## Task 6: The request page — banner, chain, actions

**Files:**
- Create: `app/views/purchase_requests/_lifecycle_banner.html.erb`
- Modify: `app/views/purchase_requests/show.html.erb`
- Modify: `assets/stylesheets/purchase_requests.css`

- [ ] **Step 1: Create the banner partial**

```erb
<%#
  Shown only when the request is not active. Both states name their successor
  or their reason, because "this does not count" without "why" sends the
  reader to ask someone.
%>
<% if request_record.superseded? && request_record.superseded_by %>
  <div class="pr-alert pr-alert-info pr-block-gap">
    <strong><%= l(:label_superseded_by) %></strong>
    <%= link_to "##{request_record.superseded_by.id} — #{request_record.superseded_by.title}",
                purchase_request_path(request_record.superseded_by) %>
    <span class="pr-hint"><%= l(:text_superseded_no_budget) %></span>
  </div>
<% elsif request_record.cancelled? %>
  <div class="pr-alert pr-alert-warning pr-block-gap">
    <strong><%= l(:label_cancelled_on, date: format_date(request_record.cancelled_at)) %></strong>
    <%= request_record.cancelled_by&.name %>
    <p class="pr-hint"><%= request_record.cancellation_reason %></p>
  </div>
<% end %>
```

- [ ] **Step 2: Render it, with the chain and buttons, in `show.html.erb`**

Immediately after the `<h2>`:

```erb
<%= render 'purchase_requests/lifecycle_banner', request_record: @purchase_request %>

<% if @purchase_request.revision_of || @purchase_request.superseded_by %>
  <p class="pr-hint">
    <%= l(:label_revision_number, number: @purchase_request.revision_number) %>
    <% if @purchase_request.revision_of %>
      · <%= link_to l(:label_revision_of) + " ##{@purchase_request.revision_of.id}",
                    purchase_request_path(@purchase_request.revision_of) %>
    <% end %>
  </p>
<% end %>
```

In the existing `.contextual` block:

```erb
<% if @purchase_request.revisable? && User.current.allowed_to?(:revise_purchase_requests, @project) %>
  <%= link_to l(:button_revise), revise_purchase_request_path(@purchase_request),
              method: :post, class: 'pr-button pr-button-secondary' %>
<% end %>
<% if @purchase_request.cancellable? && User.current.allowed_to?(:cancel_purchase_requests, @project) %>
  <%= link_to l(:button_cancel_request), cancel_purchase_request_path(@purchase_request),
              class: 'pr-button pr-button-danger' %>
<% end %>
<% if @purchase_request.uncancellable? && User.current.allowed_to?(:cancel_purchase_requests, @project) %>
  <%= link_to l(:button_reinstate_request), uncancel_purchase_request_path(@purchase_request),
              method: :post, class: 'pr-button pr-button-secondary' %>
<% end %>
```

- [ ] **Step 3: Add the locale keys**

```yaml
  label_cancelled_on: "Cancelled %{date} by"
  text_superseded_no_budget: "This version no longer counts toward budget."
  button_revise: "Revise"
```

- [ ] **Step 4: Run the gates**

```bash
cd /opt/redmine
bundle exec rake redmine_purchase_requests:check_templates && bundle exec rake redmine_purchase_requests:ratchet
```
Expected: both clean. The ratchet fails if the new markup adds an inline `style=`; the partial uses existing classes only.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(lifecycle): show lifecycle state and the revision chain on a request"
```

---

## Task 7: Make the CAPEX and OPEX lists reconcile with their totals

The linked-request tables live on the show pages, not in the entries-table
partials. The two pages use **different instance variable names** — that is
the trap in this task.

**Files:**
- Modify: `app/views/capex/show.html.erb:189-207` — iterates `@purchase_requests`
- Modify: `app/views/opex/show.html.erb:169-172` — iterates `@linked_requests`
- Modify: `assets/stylesheets/purchase_requests.css`
- Modify: `config/locales/en.yml`

**Interfaces:**
- Consumes: `#counts_toward_budget?` from Task 1.

- [ ] **Step 1: Mute and annotate the CAPEX rows**

`app/views/capex/show.html.erb`, replace line 208:

```erb
              <tr class="<%= cycle('odd', 'even') %> <%= 'pr-row--void' unless pr.counts_toward_budget? %>">
```

and in the id cell immediately below it, after the existing link:

```erb
                  <% unless pr.counts_toward_budget? %>
                    <span class="pr-hint"><%= l(:text_does_not_count_toward_budget) %></span>
                  <% end %>
```

- [ ] **Step 2: Say how many of the listed requests count**

Replace line 191:

```erb
      <% counting = @purchase_requests.count(&:counts_toward_budget?) %>
      <h4>
        <%= l(:label_linked_purchase_requests) %> (<%= @purchase_requests.count %>)
        <% if counting < @purchase_requests.count %>
          <span class="pr-hint"><%= l(:text_n_count_toward_budget, count: counting) %></span>
        <% end %>
      </h4>
```

This is the reconciliation: a reader seeing five rows and a utilised figure
covering three now has the arithmetic stated rather than having to infer it.

- [ ] **Step 3: Do the same for OPEX**

`app/views/opex/show.html.erb` around lines 169-172. The collection is
`@linked_requests`, **not** `@purchase_requests` — copying the CAPEX block
verbatim will render an empty table with no error, which is the failure mode
to watch for here.

- [ ] **Step 4: Add the styles, tokens only**

Appended to `assets/stylesheets/purchase_requests.css`:

```css
/* A row that is listed but not counted. Without the distinction, a table of
   five requests beside a total covering three reads as a defect rather than
   as a fact about cancelled work. */
#content .pr-row--void td { color: var(--pr-ink-faint); }
#content .pr-row--void .capex-amount,
#content .pr-row--void .opex-amount { text-decoration: line-through; }
```

- [ ] **Step 5: Add the locale keys**

```yaml
  label_linked_purchase_requests: "Linked purchase requests"
  text_does_not_count_toward_budget: "does not count toward budget"
  text_n_count_toward_budget: "%{count} count toward budget"
```

The existing headings are hardcoded English; replacing them with a key is
in scope here because the line is being edited anyway.

- [ ] **Step 6: Check both pages render**

```bash
cd /opt/redmine
bundle exec rake redmine_purchase_requests:check_templates
bundle exec rake redmine_purchase_requests:ratchet
```
Expected: templates compile; the ratchet does not grow. The new markup adds no
inline `style=` and no raw hex, which is what the ratchet would otherwise
catch.

- [ ] **Step 7: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add app/views/capex/show.html.erb app/views/opex/show.html.erb assets/stylesheets/purchase_requests.css config/locales/en.yml
git commit -m "feat(budget): show why a listed request is not in the total

A CAPEX page listing five linked requests beside a utilised figure covering
three reads as a defect. Non-counting rows are now muted with their amount
struck through and annotated, and the heading states how many of the listed
requests count.

The two pages iterate different variables -- @purchase_requests on CAPEX,
@linked_requests on OPEX -- so the blocks are not interchangeable; copying one
to the other renders an empty table silently."

```

---

## Task 8: Lifecycle on the list, and a filter

**Files:**
- Modify: `app/views/purchase_requests/index.html.erb`
- Modify: `app/controllers/purchase_requests_controller.rb` (index action)

- [ ] **Step 1: Filter in the controller**

In `index`, beside the existing status filter:

```ruby
    # Every lifecycle is listed by default: hiding superseded requests would
    # surprise someone searching for one they know exists.
    if params[:lifecycle].present? && PurchaseRequest::LIFECYCLES.include?(params[:lifecycle])
      scope = scope.where(lifecycle: params[:lifecycle])
    end
```

- [ ] **Step 2: Add the select to the filter row**

```erb
<label for="lifecycle"><%= l(:field_lifecycle) %></label>
<%= select_tag 'lifecycle',
      options_for_select([[l(:label_all), '']] +
        PurchaseRequest::LIFECYCLES.map { |v| [l("label_lifecycle_#{v}"), v] },
        params[:lifecycle]),
      id: 'lifecycle' %>
```

- [ ] **Step 3: Mute superseded rows and link to the successor**

```erb
<tr class="<%= 'pr-row--void' unless request.counts_toward_budget? %>">
```

- [ ] **Step 4: Locale keys**

```yaml
  field_lifecycle: "Lifecycle"
  label_lifecycle_active: "Active"
  label_lifecycle_cancelled: "Cancelled"
  label_lifecycle_superseded: "Superseded"
```

- [ ] **Step 5: Run the gates, the full suite, and commit**

```bash
cd /opt/redmine
bundle exec rake redmine_purchase_requests:check_templates
bundle exec rake redmine_purchase_requests:ratchet
RAILS_ENV=test bundle exec rake redmine:plugins:test NAME=redmine_purchase_requests
```
Expected: gates clean; suite no worse than the Task 0 baseline, plus the new tests passing.

```bash
cd plugins/redmine_purchase_requests && git add -A
git commit -m "feat(lifecycle): show and filter lifecycle on the request list"
```

---

## Task 9: Deploy

- [ ] **Step 1: Run the migration on production**

```bash
cd /opt/redmine
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests
```
Expected: `041 AddLifecycleToPurchaseRequests: migrated`. The migration is inert — every existing request becomes `active` from the column default, so no figure changes.

- [ ] **Step 2: Confirm nothing moved**

```bash
cd /opt/redmine
RAILS_ENV=production bundle exec rails runner '
  puts "requests: #{PurchaseRequest.count}, active: #{PurchaseRequest.budgeted.count}"
  Capex.limit(5).each { |c| puts "  capex #{c.id}: utilized #{c.utilized_amount}" }
'
```
Expected: active count equals total count; utilised figures match what they were before the migration.

- [ ] **Step 3: Restart and verify**

```bash
touch /opt/redmine/tmp/restart.txt
curl -s -o /dev/null -w '%{http_code}\n' -k https://localhost/login
```
Expected: 200.

- [ ] **Step 4: Grant the permissions**

In Redmine: Administration → Roles and permissions → grant
`revise_purchase_requests` and `cancel_purchase_requests` to whichever roles should hold them. Neither is granted by default.

---

## Notes for the executor

**The two filtering techniques are not interchangeable.** `Capex` and `Opex` filter in Ruby because their association is preloaded; everything else filters in SQL. Task 2 has a test asserting the query count stays at zero. If that test starts failing after an unrelated change, someone has rewritten the Ruby `reject` as a scoped `where`, and the N+1 is back.

**The unique index is the guard, not the code.** Task 5's "cannot be revised twice" test deliberately bypasses the model check and asserts `ActiveRecord::RecordNotUnique`. Do not replace it with a validation test.

**Counts are not money.** If a task tempts you to add `.budgeted` to something counting requests rather than summing money, stop: the spec says cancelled requests still happened.
