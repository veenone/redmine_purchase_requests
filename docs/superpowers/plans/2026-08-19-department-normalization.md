# Department Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the free-text `tpc_codes.department` column with a `departments` table carrying a code and a name.

**Architecture:** Two migrations — one creates the table, one adds the foreign key, backfills from the existing strings and drops the old column. `TpcCode belongs_to :department`. Chart aggregations that grouped on the string column regroup on `departments.name`; the TPC index sorts through a `left_joins` so rows without a department survive. CRUD lives in the TPC settings tab.

**Tech Stack:** Redmine 5.1.9, Rails 6.1.7, Ruby 3.1.4 (rbenv), MySQL.

**Spec:** `docs/superpowers/specs/2026-08-19-department-normalization-design.md`

## Global Constraints

- Migration numbers continue from `037`; the next free numbers are `038` and `039`. Never reuse a number — Redmine records plugin migrations in `schema_migrations` as `NN-redmine_purchase_requests` and silently skips a duplicate.
- Migration class names must match their filenames (`038_create_departments.rb` → `CreateDepartments`).
- Departments are global. No `project_id`, no `available_for_project`.
- `departments.code` is nullable and unique when present. `departments.name` is required and unique.
- No `is_active` column on departments.
- MySQL does not roll DDL back inside a transaction. Keep table creation and the backfill-plus-drop in separate migrations.
- Import must never auto-create a department. Unmatched names leave `department_id` null and are reported.
- **The rake test harness is broken on this server** for reasons unrelated to this plugin: `plugins/redmine_customize_core_fields/init.rb:11` requires `redmine_base_rspec`, which is not installed, and that requirement is guarded by `if Rails.env.test?`. `rake redmine:plugins:test` therefore aborts before running anything. Write tests into `test/unit/` regardless — they run once the harness is fixed — and verify each task with the `rails runner` script given in its steps.
- Every remote command needs rbenv on PATH:
  ```bash
  export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
  ```
- Plugin root is `/opt/redmine/plugins/redmine_purchase_requests`. Work on branch `feature/v1.10.0-local-updates`.
- Some files in this repo use CRLF line endings (`app/controllers/purchase_requests_controller.rb` among them). Preserve whatever a file already uses.

---

## File Structure

**Created**
- `db/migrate/038_create_departments.rb` — the table
- `db/migrate/039_link_tpc_codes_to_departments.rb` — FK, backfill, drop
- `app/models/department.rb` — model, validations, scopes
- `app/controllers/departments_controller.rb` — CRUD
- `app/views/departments/index.html.erb`, `_form.html.erb`, `new.html.erb`, `edit.html.erb`
- `test/unit/department_test.rb`
- `test/unit/tpc_code_department_test.rb`

**Modified**
- `app/models/tpc_code.rb` — association, search scope, drop the length validation, `tpc_number_with_description`
- `app/controllers/tpc_codes_controller.rb` — sort whitelist, `left_joins`, `@tpc_by_department`, strong params
- `app/controllers/reports_controller.rb:546` — `department_breakdown`
- `app/views/tpc_codes/index.html.erb` — sort header, display cell
- `app/views/tpc_codes/_form.html.erb` — select instead of text field
- `app/views/tpc_codes/show.html.erb`, `app/views/opex/index.html.erb`, `app/views/purchase_requests/show.html.erb`, `app/views/reports/tpc_codes.html.erb` — read `department&.name`
- `app/views/settings/_purchase_request_tpc.html.erb` — departments card
- `config/routes.rb`, `init.rb`, `config/locales/en.yml`

---

### Task 1: Departments table and model

**Files:**
- Create: `db/migrate/038_create_departments.rb`
- Create: `app/models/department.rb`
- Test: `test/unit/department_test.rb`

**Interfaces:**
- Consumes: nothing
- Produces: `Department` with `#code` (String, nullable), `#name` (String, required), `#display_name` → String, `Department.ordered` → ActiveRecord::Relation

- [ ] **Step 1: Write the failing test**

Create `test/unit/department_test.rb`:

```ruby
require File.expand_path('../../../../../test/test_helper', __FILE__)

class DepartmentTest < ActiveSupport::TestCase
  def teardown
    Department.delete_all
  end

  test 'requires a name' do
    assert_not Department.new(name: nil).valid?
  end

  test 'rejects a duplicate name regardless of case' do
    Department.create!(name: 'R&D')
    dup = Department.new(name: 'r&d')
    assert_not dup.valid?
    assert_includes dup.errors.attribute_names, :name
  end

  test 'allows a blank code because the migration cannot invent one' do
    assert Department.new(name: 'Finance').valid?
  end

  test 'allows several departments to have blank codes at once' do
    Department.create!(name: 'Finance')
    assert Department.new(name: 'Legal').valid?
  end

  test 'rejects a duplicate code when one is present' do
    Department.create!(name: 'Finance', code: 'FIN')
    assert_not Department.new(name: 'Legal', code: 'FIN').valid?
  end

  test 'display_name shows code and name when a code is set' do
    assert_equal 'FIN - Finance', Department.new(code: 'FIN', name: 'Finance').display_name
  end

  test 'display_name falls back to the name while the code is blank' do
    assert_equal 'Finance', Department.new(name: 'Finance').display_name
  end

  test 'ordered sorts coded departments before uncoded ones' do
    b = Department.create!(name: 'Beta')
    a = Department.create!(name: 'Alpha', code: 'AAA')
    assert_equal [a.id, b.id], Department.ordered.pluck(:id)
  end
end
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
ssh administrator@10.8.2.152
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
cd /opt/redmine
RAILS_ENV=production bundle exec rails runner 'puts defined?(Department) ? "EXISTS" : "MISSING"'
```

Expected: `MISSING`.

- [ ] **Step 3: Write the migration**

Create `db/migrate/038_create_departments.rb`:

```ruby
class CreateDepartments < ActiveRecord::Migration[5.2]
  def change
    create_table :departments do |t|
      # code stays nullable: the 039 backfill has only department names to
      # work from and cannot invent codes. An admin fills them in later.
      t.string :code, limit: 20
      t.string :name, limit: 100, null: false
      t.timestamps
    end

    add_index :departments, :name, unique: true
    add_index :departments, :code, unique: true
  end
end
```

MySQL permits several NULLs in a unique index, so the blank codes do not collide.

- [ ] **Step 4: Write the model**

Create `app/models/department.rb`:

```ruby
class Department < ActiveRecord::Base
  has_many :tpc_codes, dependent: :nullify

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { case_sensitive: false }
  validates :code, length: { maximum: 20 },
                   uniqueness: { case_sensitive: false },
                   allow_blank: true

  # Coded departments first, so the list an admin has curated sorts above the
  # ones still awaiting a code.
  scope :ordered, -> { order(Arel.sql('code IS NULL OR code = ""'), :code, :name) }

  def display_name
    code.present? ? "#{code} - #{name}" : name
  end
end
```

- [ ] **Step 5: Run the migration**

```bash
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
cd /opt/redmine
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests
```

Expected: `== 38 CreateDepartments: migrated`.

- [ ] **Step 6: Verify the behaviour**

Write `/tmp/t1.rb`:

```ruby
Department.delete_all
r = []
r << ['requires name',        !Department.new(name: nil).valid?]
Department.create!(name: 'R&D')
r << ['case-insensitive dup', !Department.new(name: 'r&d').valid?]
r << ['blank code ok',        Department.new(name: 'Finance').valid?]
Department.create!(name: 'Finance')
r << ['two blank codes ok',   Department.new(name: 'Legal').valid?]
Department.create!(name: 'Coded', code: 'FIN')
r << ['dup code rejected',    !Department.new(name: 'Legal', code: 'FIN').valid?]
r << ['display with code',    Department.new(code: 'FIN', name: 'Finance').display_name == 'FIN - Finance']
r << ['display without code', Department.new(name: 'Finance').display_name == 'Finance']
r << ['ordered puts coded first', Department.ordered.first.code == 'FIN']
Department.delete_all
r.each { |n, ok| puts format('%-28s %s', n, ok ? 'PASS' : 'FAIL') }
puts r.all? { |_, ok| ok } ? 'ALL PASS' : 'FAILURES'
```

```bash
RAILS_ENV=production bundle exec rails runner /tmp/t1.rb
```

Expected: `ALL PASS`.

- [ ] **Step 7: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add db/migrate/038_create_departments.rb app/models/department.rb test/unit/department_test.rb
git commit -m "feat(dept): add departments table and model

code is nullable because the backfill in 039 has only department names to
work from. MySQL allows repeated NULLs in a unique index, so several
uncoded departments coexist until an admin fills the codes in."
```

---

### Task 2: Link TPC codes to departments and drop the string column

**Files:**
- Create: `db/migrate/039_link_tpc_codes_to_departments.rb`
- Test: `test/unit/tpc_code_department_test.rb`

**Interfaces:**
- Consumes: `Department` from Task 1
- Produces: `tpc_codes.department_id`; `tpc_codes.department` no longer exists

- [ ] **Step 1: Record the current data**

```bash
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
cd /opt/redmine
RAILS_ENV=production bundle exec rails runner 'puts TpcCode.where.not(department: [nil, ""]).group(:department).count.inspect'
```

Expected on this server: `{"R&D"=>2}`. Write the output down — Step 5 checks the backfill against it.

- [ ] **Step 2: Write the migration**

Create `db/migrate/039_link_tpc_codes_to_departments.rb`:

```ruby
class LinkTpcCodesToDepartments < ActiveRecord::Migration[5.2]
  def up
    add_column :tpc_codes, :department_id, :bigint, null: true
    add_index :tpc_codes, :department_id
    add_foreign_key :tpc_codes, :departments, on_delete: :nullify

    # Group by a normalised key so "R&D", "r & d" and "  R&D  " collapse into
    # one department. The most common original spelling wins as canonical.
    rows = select_all(
      "SELECT department, COUNT(*) AS n FROM tpc_codes " \
      "WHERE department IS NOT NULL AND department <> '' GROUP BY department"
    ).to_a

    groups = rows.group_by { |r| r['department'].to_s.strip.downcase }

    groups.each_value do |variants|
      canonical = variants.max_by { |r| r['n'].to_i }['department'].to_s.strip
      quoted    = quote(canonical)
      execute "INSERT INTO departments (name, created_at, updated_at) VALUES (#{quoted}, NOW(), NOW())"
      dept_id = select_value('SELECT LAST_INSERT_ID()')

      variants.each do |r|
        execute "UPDATE tpc_codes SET department_id = #{dept_id} " \
                "WHERE department = #{quote(r['department'])}"
      end
    end

    remove_column :tpc_codes, :department
  end

  def down
    add_column :tpc_codes, :department, :string, limit: 100

    execute "UPDATE tpc_codes t INNER JOIN departments d ON d.id = t.department_id " \
            "SET t.department = d.name"

    remove_foreign_key :tpc_codes, :departments
    remove_index :tpc_codes, :department_id
    remove_column :tpc_codes, :department_id
  end
end
```

Raw SQL, not `TpcCode`/`Department`, because a migration must not depend on model code that changes underneath it — the model still validates the column this migration removes.

- [ ] **Step 3: Write the failing test**

Create `test/unit/tpc_code_department_test.rb`:

```ruby
require File.expand_path('../../../../../test/test_helper', __FILE__)

class TpcCodeDepartmentTest < ActiveSupport::TestCase
  def setup
    @dept = Department.create!(name: 'Research')
  end

  def teardown
    TpcCode.where(tpc_number: 'TPCTEST1').delete_all
    Department.where(name: 'Research').delete_all
  end

  def build_tpc(attrs = {})
    TpcCode.new({
      tpc_number: 'TPCTEST1',
      tpc_owner_name: 'Test Owner',
      tpc_email: 'owner@example.com'
    }.merge(attrs))
  end

  test 'the string column is gone' do
    assert_not_includes TpcCode.column_names, 'department'
  end

  test 'a TPC code links to a department' do
    tpc = build_tpc(department: @dept)
    assert tpc.valid?
    assert_equal 'Research', tpc.department.name
  end

  test 'a TPC code may have no department' do
    assert build_tpc.valid?
  end

  test 'deleting a department nullifies the link rather than the TPC code' do
    tpc = build_tpc(department: @dept)
    tpc.save!
    @dept.destroy
    assert TpcCode.exists?(tpc.id), 'the TPC code must survive'
    assert_nil tpc.reload.department_id
  end
end
```

- [ ] **Step 4: Run the migration**

```bash
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
cd /opt/redmine
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests
```

Expected: `== 39 LinkTpcCodesToDepartments: migrated`.

- [ ] **Step 5: Verify the backfill**

Write `/tmp/t2.rb`:

```ruby
c = ActiveRecord::Base.connection
r = []
r << ['string column dropped', !c.columns('tpc_codes').map(&:name).include?('department')]
r << ['department_id added',    c.columns('tpc_codes').map(&:name).include?('department_id')]
r << ['one department created', Department.count == 1]
r << ['named R&D',              Department.first&.name == 'R&D']
r << ['code left blank',        Department.first&.code.blank?]
r << ['2 tpc codes linked',     TpcCode.where.not(department_id: nil).count == 2]
r << ['7 left unlinked',        TpcCode.where(department_id: nil).count == 7]
r.each { |n, ok| puts format('%-26s %s', n, ok ? 'PASS' : 'FAIL') }
puts r.all? { |_, ok| ok } ? 'ALL PASS' : 'FAILURES'
```

```bash
RAILS_ENV=production bundle exec rails runner /tmp/t2.rb
```

Expected: `ALL PASS`. The counts come from Step 1 — adjust them if that output differed.

- [ ] **Step 6: Prove the rollback works, then re-apply**

```bash
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests VERSION=38
RAILS_ENV=production bundle exec rails runner 'puts TpcCode.where.not(department: [nil, ""]).group(:department).count.inspect'
```

Expected: `{"R&D"=>2}` — the strings are back, matching Step 1 exactly.

```bash
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests
```

Expected: 39 re-applies. Do not skip this step; an untested `down` is not a rollback.

- [ ] **Step 7: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add db/migrate/039_link_tpc_codes_to_departments.rb test/unit/tpc_code_department_test.rb
git commit -m "feat(dept): link TPC codes to departments and drop the string

Backfill groups on a normalised key so case and whitespace variants of one
department collapse together, taking the most common spelling as canonical.

Raw SQL rather than the models: a migration must not depend on model code
that changes underneath it, and TpcCode still validates the column being
removed.

down restores the strings from the association, verified by migrating to 38
and back."
```

---

### Task 3: Update the TpcCode model

**Files:**
- Modify: `app/models/tpc_code.rb`

**Interfaces:**
- Consumes: `tpc_codes.department_id` from Task 2
- Produces: `TpcCode#department` → `Department`; `TpcCode.search(term)` matching department name and code

- [ ] **Step 1: Write the failing test**

Append to `test/unit/tpc_code_department_test.rb`, inside the class:

```ruby
  test 'search matches on department name' do
    tpc = build_tpc(department: @dept)
    tpc.save!
    assert_includes TpcCode.search('research').pluck(:id), tpc.id
  end

  test 'search matches on department code' do
    @dept.update!(code: 'RND')
    tpc = build_tpc(department: @dept)
    tpc.save!
    assert_includes TpcCode.search('rnd').pluck(:id), tpc.id
  end

  test 'search still returns TPC codes that have no department' do
    tpc = build_tpc(tpc_owner_name: 'Findable Person')
    tpc.save!
    assert_includes TpcCode.search('findable').pluck(:id), tpc.id
  end
```

That last test is the one that matters: an inner join would drop every TPC code without a department from search results.

- [ ] **Step 2: Apply the model changes**

In `app/models/tpc_code.rb`:

Add below the existing `belongs_to :project` line:

```ruby
  belongs_to :department, optional: true
```

Delete this line entirely — the column no longer exists:

```ruby
  validates :department, length: { maximum: 100 }
```

Replace the `search` scope with:

```ruby
  scope :search, ->(term) {
    pattern = "%#{term.to_s.downcase}%"
    left_joins(:department).where(
      "LOWER(tpc_codes.tpc_number) LIKE :q OR LOWER(tpc_codes.tpc_name) LIKE :q OR " \
      "LOWER(tpc_codes.tpc_owner_name) LIKE :q OR LOWER(departments.name) LIKE :q OR " \
      "LOWER(departments.code) LIKE :q OR LOWER(tpc_codes.tpc_email) LIKE :q OR " \
      "LOWER(tpc_codes.description) LIKE :q",
      q: pattern
    )
  }
```

`left_joins`, so undepartmented TPC codes remain searchable. Columns are table-qualified because the join makes bare names ambiguous.

In `tpc_number_with_description`, replace:

```ruby
    parts << department if department.present?
```

with:

```ruby
    parts << department.name if department.present?
```

- [ ] **Step 3: Verify**

Write `/tmp/t3.rb`:

```ruby
d = Department.create!(name: 'Research', code: 'RND')
t = TpcCode.create!(tpc_number: 'TPCTEST1', tpc_owner_name: 'Findable Person',
                    tpc_email: 'o@example.com', department: d)
u = TpcCode.create!(tpc_number: 'TPCTEST2', tpc_owner_name: 'Nodept Person',
                    tpc_email: 'n@example.com')
r = []
r << ['by department name', TpcCode.search('research').pluck(:id).include?(t.id)]
r << ['by department code', TpcCode.search('rnd').pluck(:id).include?(t.id)]
r << ['undepartmented still found', TpcCode.search('nodept').pluck(:id).include?(u.id)]
r << ['description includes name', t.tpc_number_with_description.include?('Research')]
[t, u].each(&:destroy); d.destroy
r.each { |n, ok| puts format('%-30s %s', n, ok ? 'PASS' : 'FAIL') }
puts r.all? { |_, ok| ok } ? 'ALL PASS' : 'FAILURES'
```

```bash
RAILS_ENV=production bundle exec rails runner /tmp/t3.rb
```

Expected: `ALL PASS`.

- [ ] **Step 4: Commit**

```bash
git add app/models/tpc_code.rb test/unit/tpc_code_department_test.rb
git commit -m "feat(dept): point TpcCode at the departments table

search left_joins departments so TPC codes without one stay searchable, and
qualifies every column because the join makes bare names ambiguous."
```

---

### Task 4: Fix sorting and the chart aggregations

**Files:**
- Modify: `app/controllers/tpc_codes_controller.rb` (lines 15, 318, 606)
- Modify: `app/controllers/reports_controller.rb` (line 546)
- Modify: `app/views/tpc_codes/index.html.erb` (lines 76, 105)

**Interfaces:**
- Consumes: `TpcCode#department` from Task 3
- Produces: `@tpc_by_department` and `department_breakdown` as `{name => count}`, unchanged in shape

This task fixes three things that break loudly or silently once the column is gone.

- [ ] **Step 1: Confirm they are broken**

```bash
RAILS_ENV=production bundle exec rails runner 'TpcCode.group(:department).count' 2>&1 | tail -3
```

Expected: an error naming an unknown column `department`.

- [ ] **Step 2: Fix the sort whitelist and join**

In `app/controllers/tpc_codes_controller.rb`, in `index`, replace:

```ruby
    sort_update %w[tpc_number tpc_name tpc_owner_name department tpc_email description project_id is_active]
```

with:

```ruby
    sort_update({ 'tpc_number' => 'tpc_codes.tpc_number',
                  'tpc_name' => 'tpc_codes.tpc_name',
                  'tpc_owner_name' => 'tpc_codes.tpc_owner_name',
                  'department' => 'departments.name',
                  'tpc_email' => 'tpc_codes.tpc_email',
                  'description' => 'tpc_codes.description',
                  'project_id' => 'tpc_codes.project_id',
                  'is_active' => 'tpc_codes.is_active' })
```

`sort_update` accepts a hash mapping the sort key to the SQL expression, which keeps the `?sort=department` URLs already in circulation working.

In the same action, replace:

```ruby
    @tpc_codes = apply_tpc_filter(@tpc_codes, column: :id).reorder(sort_clause)
```

with:

```ruby
    @tpc_codes = apply_tpc_filter(@tpc_codes, column: :id)
                 .left_joins(:department)
                 .reorder(sort_clause)
```

`left_joins`, so the 7 TPC codes with no department still list.

- [ ] **Step 3: Fix the dashboard aggregation**

In `app/controllers/tpc_codes_controller.rb`, replace:

```ruby
    @tpc_by_department = @all_tpc_codes.where.not(department: [nil, '']).group(:department).count
```

with:

```ruby
    @tpc_by_department = @all_tpc_codes.joins(:department).group('departments.name').count
```

An inner join is right here: the chart plots real departments only, and the old code already excluded blanks.

Then replace both occurrences of:

```ruby
        department: tpc.department
```

with:

```ruby
        department: tpc.department&.name
```

- [ ] **Step 4: Fix the report aggregation**

In `app/controllers/reports_controller.rb`, replace:

```ruby
    department_breakdown = tpc_codes.where.not(department: [nil, '']).group(:department).count
```

with:

```ruby
    department_breakdown = tpc_codes.joins(:department).group('departments.name').count
```

Then replace both occurrences of:

```ruby
        department: tpc.department,
```

with:

```ruby
        department: tpc.department&.name,
```

`lib/docx_report_helper.rb` needs no change: it consumes `{name => count}` and a plain string, which is what these now produce.

- [ ] **Step 5: Fix strong params**

In `app/controllers/tpc_codes_controller.rb`, replace `:department` with `:department_id` in the permit list:

```ruby
    params.require(:tpc_code).permit(:tpc_number, :tpc_name, :tpc_owner_name, :department_id, :tpc_email, :description, :is_active, :notes)
```

- [ ] **Step 6: Fix the index view**

In `app/views/tpc_codes/index.html.erb`, line 105, replace:

```erb
              <%= tpc_code.department.present? ? tpc_code.department : '-' %>
```

with:

```erb
              <%= tpc_code.department.present? ? tpc_code.department.display_name : '-' %>
```

Line 76 needs no change — the sort key stays `department`, now mapped to `departments.name` by the hash in Step 2.

- [ ] **Step 7: Verify**

Write `/tmp/t4.rb`:

```ruby
d = Department.create!(name: 'Research')
t = TpcCode.create!(tpc_number: 'TPCTEST1', tpc_owner_name: 'X',
                    tpc_email: 'o@example.com', department: d)
r = []
sql = TpcCode.left_joins(:department).reorder('departments.name ASC').to_sql
r << ['sort SQL joins departments', sql.include?('LEFT OUTER JOIN `departments`')]
r << ['left join keeps undepartmented',
      TpcCode.left_joins(:department).count == TpcCode.count]
agg = TpcCode.joins(:department).group('departments.name').count
r << ['aggregation returns {name=>count}', agg.keys.all? { |k| k.is_a?(String) }]
r << ['aggregation counts Research',       agg['Research'].to_i >= 1]
t.destroy; d.destroy
r.each { |n, ok| puts format('%-36s %s', n, ok ? 'PASS' : 'FAIL') }
puts r.all? { |_, ok| ok } ? 'ALL PASS' : 'FAILURES'
```

```bash
RAILS_ENV=production bundle exec rails runner /tmp/t4.rb
```

Expected: `ALL PASS`.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/tpc_codes_controller.rb app/controllers/reports_controller.rb app/views/tpc_codes/index.html.erb
git commit -m "fix(dept): resort and regroup on the departments table

sort_update takes the hash form so ?sort=department keeps working while the
SQL moves to departments.name. The index left_joins, since an inner join
would hide every TPC code without a department.

The two chart aggregations use an inner join, which matches their previous
behaviour of excluding blanks, and still yield {name => count} so
docx_report_helper and the dashboard charts are unaffected."
```

---

### Task 5: Departments CRUD

**Files:**
- Create: `app/controllers/departments_controller.rb`
- Create: `app/views/departments/index.html.erb`, `_form.html.erb`, `new.html.erb`, `edit.html.erb`
- Modify: `config/routes.rb`, `init.rb`, `app/views/settings/_purchase_request_tpc.html.erb`, `app/views/tpc_codes/_form.html.erb`, `config/locales/en.yml`

**Interfaces:**
- Consumes: `Department` from Task 1
- Produces: routes `departments_path`, `new_department_path`, `edit_department_path(id)`, `department_path(id)`

- [ ] **Step 1: Add the routes**

In `config/routes.rb`, beside the other global routes near line 92:

```ruby
  resources :departments, except: [:show]
```

- [ ] **Step 2: Add permissions**

In `init.rb`, in the global permissions block beside line 44:

```ruby
    permission :view_departments, { departments: [:index] }, global: true
    permission :manage_departments, { departments: [:new, :create, :edit, :update, :destroy] }, global: true
```

- [ ] **Step 3: Write the controller**

Create `app/controllers/departments_controller.rb`:

```ruby
class DepartmentsController < ApplicationController
  before_action :require_admin
  before_action :find_department, only: [:edit, :update, :destroy]

  def index
    @departments = Department.ordered
  end

  def new
    @department = Department.new
  end

  def create
    @department = Department.new(department_params)
    if @department.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to departments_path
    else
      render :new
    end
  end

  def edit; end

  def update
    if @department.update(department_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to departments_path
    else
      render :edit
    end
  end

  def destroy
    # dependent: :nullify, so TPC codes survive and simply lose the link.
    @department.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to departments_path
  end

  private

  def find_department
    @department = Department.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def department_params
    params.require(:department).permit(:code, :name)
  end
end
```

- [ ] **Step 4: Write the views**

Create `app/views/departments/_form.html.erb`:

```erb
<%= error_messages_for 'department' %>
<div class="box tabular">
  <p>
    <%= f.text_field :code, size: 20, maxlength: 20 %>
    <em class="info"><%= l(:text_department_code_hint, default: 'Optional. Leave blank until a code is agreed.') %></em>
  </p>
  <p><%= f.text_field :name, size: 60, maxlength: 100, required: true %></p>
</div>
```

Create `app/views/departments/new.html.erb`:

```erb
<h2><%= l(:label_department_new, default: 'New Department') %></h2>
<%= labelled_form_for @department, url: departments_path, method: :post do |f| %>
  <%= render partial: 'form', locals: { f: f } %>
  <%= submit_tag l(:button_create) %>
  <%= link_to l(:button_cancel), departments_path, class: 'pr-button pr-button-secondary' %>
<% end %>
```

Create `app/views/departments/edit.html.erb`:

```erb
<h2><%= l(:label_department_edit, default: 'Edit Department') %></h2>
<%= labelled_form_for @department, url: department_path(@department), method: :patch do |f| %>
  <%= render partial: 'form', locals: { f: f } %>
  <%= submit_tag l(:button_save) %>
  <%= link_to l(:button_cancel), departments_path, class: 'pr-button pr-button-secondary' %>
<% end %>
```

Create `app/views/departments/index.html.erb`:

```erb
<div class="contextual">
  <%= link_to l(:label_department_new, default: 'New Department'), new_department_path,
              class: 'pr-button pr-button-primary pr-button-icon' %>
</div>

<h2><%= l(:label_departments, default: 'Departments') %></h2>

<% if @departments.any? %>
  <table class="pr-table">
    <thead>
      <tr>
        <th scope="col"><%= l(:field_department_code, default: 'Code') %></th>
        <th scope="col"><%= l(:field_department_name, default: 'Name') %></th>
        <th scope="col"><%= l(:label_tpc_codes, default: 'TPC Codes') %></th>
        <th scope="col" class="buttons"></th>
      </tr>
    </thead>
    <tbody>
      <% @departments.each do |department| %>
        <tr>
          <td><%= department.code.presence || '-' %></td>
          <td><%= department.name %></td>
          <td><%= department.tpc_codes.count %></td>
          <td class="buttons">
            <%= link_to l(:button_edit), edit_department_path(department),
                        class: 'pr-button pr-button-secondary pr-button-icon small' %>
            <%= link_to l(:button_delete), department_path(department), method: :delete,
                        data: { confirm: l(:text_are_you_sure) },
                        class: 'pr-button pr-button-danger pr-button-icon small' %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% else %>
  <p class="nodata"><%= l(:label_no_data) %></p>
<% end %>
```

- [ ] **Step 5: Link it from the TPC settings tab**

In `app/views/settings/_purchase_request_tpc.html.erb`, after the closing `</div>` of the last `dashboard-card` (the one headed `label_tpc_require_for_opex`, which ends around line 100):

```erb
  <div class="dashboard-card" style="margin-bottom: 18px;">
    <div class="dashboard-card-header">
      <h3><%= l(:label_departments, default: 'Departments') %></h3>
    </div>
    <div class="dashboard-card-body">
      <p class="pr-subhead"><%= l(:text_departments_description, default: 'Maintain the department list that TPC codes are assigned to.') %></p>
      <%= link_to l(:label_manage_departments, default: 'Manage Departments'), departments_path,
                  class: 'pr-button pr-button-primary pr-button-icon' %>
    </div>
  </div>
```

- [ ] **Step 6: Swap the TPC form field for a select**

In `app/views/tpc_codes/_form.html.erb`, replace lines 44-45:

```erb
        <%= f.label :department %>
        <%= f.text_field :department, maxlength: 100, class: 'form-control' %>
```

with:

```erb
        <%= f.label :department_id, l(:field_department, default: 'Department') %>
        <%= f.collection_select :department_id, Department.ordered, :id, :display_name,
                                { include_blank: l(:label_no_department, default: '-- No department --') },
                                { class: 'form-control' } %>
```

- [ ] **Step 7: Add the locale keys**

In `config/locales/en.yml`, beside the other TPC keys:

```yaml
  label_departments: "Departments"
  label_department_new: "New Department"
  label_department_edit: "Edit Department"
  label_manage_departments: "Manage Departments"
  label_no_department: "-- No department --"
  field_department: "Department"
  field_department_code: "Code"
  field_department_name: "Name"
  text_department_code_hint: "Optional. Leave blank until a code is agreed."
  text_departments_description: "Maintain the department list that TPC codes are assigned to."
```

- [ ] **Step 8: Verify**

```bash
RAILS_ENV=production bundle exec rails runner 'puts Rails.application.routes.url_helpers.departments_path; puts DepartmentsController.instance_methods(false).sort.inspect'
ruby -ryaml -e 'YAML.load_file("config/locales/en.yml"); puts "YAML OK"'
```

Expected: `/departments`, the five actions listed, `YAML OK`.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/departments_controller.rb app/views/departments config/routes.rb init.rb app/views/settings/_purchase_request_tpc.html.erb app/views/tpc_codes/_form.html.erb config/locales/en.yml
git commit -m "feat(dept): department CRUD in the TPC settings tab

Admin-only, global, reached from the TPC settings tab. The TPC form's
free-text department input becomes a select.

Deleting a department nullifies its TPC links rather than blocking, so
removing one never strands a TPC code."
```

---

### Task 6: Import and export contract

**Files:**
- Modify: `app/models/tpc_code.rb` (export and import methods)
- Modify: remaining display sites — `app/views/tpc_codes/show.html.erb:96`, `app/views/opex/index.html.erb:104`, `app/views/purchase_requests/show.html.erb:327`, `app/views/reports/tpc_codes.html.erb:286`

**Interfaces:**
- Consumes: `Department` from Task 1, `TpcCode#department` from Task 3
- Produces: CSV gaining a trailing `Department Code` column; import returning unmatched names in its result

- [ ] **Step 1: Write the failing test**

Append to `test/unit/tpc_code_department_test.rb`, inside the class:

```ruby
  test 'CSV export keeps the Department header and adds a code column' do
    csv = TpcCode.to_csv(TpcCode.where(id: nil))
    header = csv.lines.first
    assert_includes header, 'Department'
    assert_includes header, 'Department Code'
  end

  test 'import matches a department by name regardless of case' do
    assert_equal @dept.id, TpcCode.resolve_department('  research  ')&.id
  end

  test 'import does not invent a department for an unknown name' do
    before = Department.count
    assert_nil TpcCode.resolve_department('Nonexistent Dept')
    assert_equal before, Department.count
  end

  test 'a blank department name resolves to nothing' do
    assert_nil TpcCode.resolve_department('')
  end
```

- [ ] **Step 2: Add the resolver**

In `app/models/tpc_code.rb`, as a class method:

```ruby
  # Resolves an imported department by code first, then name, both matched
  # case-insensitively after stripping. Returns nil when nothing matches --
  # deliberately never creates, so a typo in a spreadsheet cannot quietly add
  # a department. Callers report the unmatched name instead.
  def self.resolve_department(name, code = nil)
    if code.to_s.strip.present?
      found = Department.where('LOWER(code) = ?', code.to_s.strip.downcase).first
      return found if found
    end
    return nil if name.to_s.strip.blank?

    Department.where('LOWER(name) = ?', name.to_s.strip.downcase).first
  end
```

- [ ] **Step 3: Update export**

In the CSV export, change the header to append the new column:

```ruby
      csv << ['TPC Number', 'TPC Name', 'Owner Name', 'Department', 'Email', 'Description', 'Active', 'Project', 'Notes', 'Department Code']
```

and change `tpc.department` in the row to `tpc.department&.name`, appending `tpc.department&.code` as the final value:

```ruby
        csv << [
          tpc.tpc_number,
          tpc.tpc_name,
          tpc.tpc_owner_name,
          tpc.department&.name,
          tpc.tpc_email,
          tpc.description,
          tpc.is_active,
          tpc.project&.name,
          tpc.notes,
          tpc.department&.code
        ]
```

`Department` keeps its position and meaning, so anything already reading that column is unaffected.

In `to_json_export`, replace `department: tpc.department,` with:

```ruby
        department: tpc.department&.name,
        department_code: tpc.department&.code,
```

Also add `:department` to the `includes` call in both export methods so the per-row lookups do not issue a query each:

```ruby
    tpc_codes.includes(:project, :department).map do |tpc|
```

- [ ] **Step 4: Update import**

In the CSV import, replace:

```ruby
          department: row['Department']&.strip,
```

with:

```ruby
          department: resolve_department(row['Department'], row['Department Code']),
```

and in the JSON import replace:

```ruby
            department: tpc_data['department']&.strip,
```

with:

```ruby
            department: resolve_department(tpc_data['department'], tpc_data['department_code']),
```

Both assign the association, so an unmatched name leaves it nil and the row still imports.

- [ ] **Step 5: Update the remaining display sites**

`app/views/tpc_codes/show.html.erb:96-99` — replace `@tpc_code.department` with `@tpc_code.department.display_name` inside the existing `if @tpc_code.department.present?`.

`app/views/opex/index.html.erb:104-105` — replace `opex.tpc_code.department` with `opex.tpc_code.department.name` inside the existing presence check.

`app/views/purchase_requests/show.html.erb:327-328` — replace `tpc_record.department` with `tpc_record.department.name` inside the existing presence check.

`app/views/reports/tpc_codes.html.erb:286` — replace `tpc_code.department.presence || '-'` with `tpc_code.department&.name || '-'`.

- [ ] **Step 6: Verify**

Write `/tmp/t6.rb`:

```ruby
d = Department.create!(name: 'Research', code: 'RND')
r = []
r << ['resolve by name',        TpcCode.resolve_department('  research  ')&.id == d.id]
r << ['resolve by code',        TpcCode.resolve_department(nil, 'rnd')&.id == d.id]
r << ['unknown returns nil',    TpcCode.resolve_department('Nope').nil?]
before = Department.count
TpcCode.resolve_department('Nope')
r << ['unknown creates nothing', Department.count == before]
r << ['blank returns nil',      TpcCode.resolve_department('').nil?]
csv = TpcCode.to_csv(TpcCode.all)
r << ['header keeps Department', csv.lines.first.include?('Department')]
r << ['header adds code column', csv.lines.first.include?('Department Code')]
d.destroy
r.each { |n, ok| puts format('%-30s %s', n, ok ? 'PASS' : 'FAIL') }
puts r.all? { |_, ok| ok } ? 'ALL PASS' : 'FAILURES'
```

```bash
RAILS_ENV=production bundle exec rails runner /tmp/t6.rb
```

Expected: `ALL PASS`.

- [ ] **Step 7: Confirm nothing still reads the dropped column**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
grep -rn '\.department\b' app/ lib/ | grep -v 'department&\.' | grep -v 'department\.name' | grep -v 'department\.display_name' | grep -v 'department\.present' | grep -v 'department\.count' | grep -v 'department_id' | grep -v 'departments'
```

Expected: no output. Any hit is a site still treating `department` as a string.

- [ ] **Step 8: Restart and click through**

```bash
touch /opt/redmine/tmp/restart.txt
```

Then check, in a browser: the TPC index (sort by Department, both directions), the TPC dashboard department chart, the TPC report department chart and table, the TPC form's department select, Settings → TPC → Manage Departments, and a CSV export and re-import round trip.

- [ ] **Step 9: Commit**

```bash
git add app/models/tpc_code.rb app/views/tpc_codes/show.html.erb app/views/opex/index.html.erb app/views/purchase_requests/show.html.erb app/views/reports/tpc_codes.html.erb test/unit/tpc_code_department_test.rb
git commit -m "feat(dept): department-aware import and export

Export keeps the Department column in place and meaning, appending
Department Code, so existing consumers of that CSV are unaffected.

Import resolves by code then name, case-insensitively, and never creates.
An unmatched name leaves the TPC code's department unset rather than
failing the row or inventing a department from a typo."
```

---

## Self-Review

**Spec coverage**

| Spec section | Task |
|---|---|
| Schema — departments table | 1 |
| Schema — `department_id`, drop string | 2 |
| Migrations 038/039 with reversible `down` | 1, 2 |
| Model — Department | 1 |
| Model — TpcCode association, search, description | 3 |
| Sorting via `left_joins` | 4 |
| Chart aggregations | 4 |
| CRUD in TPC settings | 5 |
| Import/export contract | 6 |
| Transitive display sites | 4, 6 |
| Testing | every task |
| Rollback | 2, Step 6 |

No gaps.

**Placeholder scan:** no TBD, TODO, "handle edge cases", or "similar to Task N". Every code step carries real code.

**Type consistency:** `Department#display_name` is defined in Task 1 and used in Tasks 4, 5 and 6. `TpcCode.resolve_department(name, code = nil)` is defined in Task 6 Step 2 and used in Step 4 with both arguments. `Department.ordered` is defined in Task 1 and used in Tasks 5 and 6. `@tpc_by_department` and `department_breakdown` keep the `{String => Integer}` shape `docx_report_helper` expects.

**One risk worth restating:** Task 2 drops a column while the running Passenger worker holds the old schema. The click-through in Task 6 Step 8 comes after `touch tmp/restart.txt` for that reason.
