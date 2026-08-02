# TPC Dashboard Filters, TPC Name Field, and UI/UX Review — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a descriptive TPC Name field surfaced across all TPC surfaces, add a "filter by TPC number" control to all four dashboards, and produce a prioritized UI/UX improvement report.

**Architecture:** Rails/Redmine plugin. Feature 2 (TPC name) is a migration + model + view change that flows into dropdown labels automatically via existing display helpers. Feature 1 mirrors the existing year-filter pattern per dashboard controller/view. Feature 3 is an audit deliverable (agents) followed by a separately-approved implementation phase.

**Tech Stack:** Ruby on Rails (Redmine 6.x / Rails 6.1 era), ERB views, MySQL, the plugin's `pr-` CSS design system.

## Global Constraints

- Redmine root: `/opt/redmine`. Plugin root: `/opt/redmine/plugins/redmine_purchase_requests`. Branch: `feature/tpc-filters-name-uiux`.
- `tpc_name` is **optional / nullable**, max length **150**. No backfill. Not unique, not required.
- No automated test suite exists in this plugin. "Verify" steps use `bundle exec rails runner` sanity checks (run from `/opt/redmine`, `RAILS_ENV=production`) and manual browser checks — NOT unit-test files.
- Do **not** touch non-live dashboard variants (`*_clean.html.erb`, `*_backup.html.erb`).
- PR dashboard TPC filter uses the PR's **direct** `tpc_code_id` only.
- Migration runs with: `cd /opt/redmine && RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests`. Restart Redmine after Ruby changes.
- Commit after each task on the feature branch.

---

## File Structure

- `db/migrate/032_add_name_to_tpc_codes.rb` — **create** — adds `tpc_name` column + index.
- `app/models/tpc_code.rb` — **modify** — validation, search scope, display helpers, CSV/JSON export+import.
- `app/controllers/tpc_codes_controller.rb` — **modify** — permit `tpc_name`.
- `app/views/tpc_codes/_form.html.erb` — **modify** — TPC Name input.
- `app/views/tpc_codes/index.html.erb` — **modify** — Name column.
- `app/views/tpc_codes/show.html.erb` — **modify** — Name field.
- `app/views/tpc_codes/import_export.html.erb` — **modify** — document TPC Name column.
- `lib/docx_report_helper.rb` — **modify** — TPC name column in TPC report table.
- `app/controllers/capex_controller.rb` + `app/views/capex/dashboard.html.erb` — **modify** — TPC filter.
- `app/controllers/opex_controller.rb` + `app/views/opex/dashboard.html.erb` — **modify** — TPC filter.
- `app/controllers/purchase_requests_controller.rb` + `app/views/purchase_requests/dashboard.html.erb` — **modify** — TPC filter.
- `app/controllers/tpc_codes_controller.rb` + `app/views/tpc_codes/dashboard.html.erb` — **modify** — TPC filter.
- `docs/superpowers/specs/2026-08-02-uiux-review-findings.md` — **create** — UI/UX report (Task 8).

---

## Task 1: Migration + Model for `tpc_name`

**Files:**
- Create: `db/migrate/032_add_name_to_tpc_codes.rb`
- Modify: `app/models/tpc_code.rb`

**Interfaces:**
- Produces: `TpcCode#tpc_name` (String, nullable); `display_name` and `tpc_number_with_description` now include the name when present; CSV header gains `TPC Name`; JSON export/import key `tpc_name`.

- [ ] **Step 1: Create the migration**

Create `db/migrate/032_add_name_to_tpc_codes.rb`:

```ruby
class AddNameToTpcCodes < ActiveRecord::Migration[5.2]
  def change
    add_column :tpc_codes, :tpc_name, :string, limit: 150, null: true
    add_index :tpc_codes, :tpc_name
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `cd /opt/redmine && RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests`
Expected: output shows `AddNameToTpcCodes: migrated`.

- [ ] **Step 3: Verify the column exists**

Run: `cd /opt/redmine && RAILS_ENV=production bundle exec rails runner "puts TpcCode.column_names.include?('tpc_name')"`
Expected: `true`

- [ ] **Step 4: Add validation and search to the model**

In `app/models/tpc_code.rb`, after the `validates :department` line add:

```ruby
  validates :tpc_name, length: { maximum: 150 }
```

Replace the `search` scope body so it also matches `tpc_name`:

```ruby
  scope :search, ->(term) {
    where("LOWER(tpc_number) LIKE ? OR LOWER(tpc_name) LIKE ? OR LOWER(tpc_owner_name) LIKE ? OR LOWER(department) LIKE ? OR LOWER(tpc_email) LIKE ? OR LOWER(description) LIKE ?",
          "%#{term.to_s.downcase}%", "%#{term.to_s.downcase}%", "%#{term.to_s.downcase}%", "%#{term.to_s.downcase}%", "%#{term.to_s.downcase}%", "%#{term.to_s.downcase}%")
  }
```

- [ ] **Step 5: Update the display helpers**

Replace `display_name`:

```ruby
  def display_name
    parts = [tpc_number]
    parts << tpc_name if tpc_name.present?
    parts << department if department.present?
    parts << tpc_owner_name
    parts.join(' - ')
  end
```

Replace `tpc_number_with_description`:

```ruby
  def tpc_number_with_description
    parts = [tpc_number]
    parts << tpc_name if tpc_name.present?
    parts << department if department.present?
    if description.present?
      parts << description.truncate(50)
    else
      parts << tpc_owner_name
    end
    parts.join(' - ')
  end
```

- [ ] **Step 6: Update CSV/JSON export and import**

In `self.to_csv`, change the header row and the cell row to include `TPC Name` right after `TPC Number`:

```ruby
      csv << ['TPC Number', 'TPC Name', 'Owner Name', 'Department', 'Email', 'Description', 'Active', 'Project', 'Notes']

      tpc_codes.includes(:project).each do |tpc|
        csv << [
          tpc.tpc_number,
          tpc.tpc_name,
          tpc.tpc_owner_name,
          tpc.department,
          tpc.tpc_email,
          tpc.description,
          tpc.is_active,
          tpc.project&.name,
          tpc.notes
        ]
      end
```

In `self.to_json_export`, add `tpc_name: tpc.tpc_name,` right after the opening `{` (before `tpc_number:`... keep existing keys). Result map hash:

```ruby
      {
        tpc_number: tpc.tpc_number,
        tpc_name: tpc.tpc_name,
        tpc_owner_name: tpc.tpc_owner_name,
        department: tpc.department,
        tpc_email: tpc.tpc_email,
        description: tpc.description,
        is_active: tpc.is_active,
        project_name: tpc.project&.name,
        notes: tpc.notes
      }
```

In `self.import_from_csv`, add to the `tpc_data` hash: `tpc_name: row['TPC Name']&.strip,` (right after `tpc_number:`).

In `self.import_from_json`, add to the `data` hash: `tpc_name: tpc_data['tpc_name']&.strip,` (right after `tpc_number:`).

- [ ] **Step 7: Verify model behavior**

Run: `cd /opt/redmine && RAILS_ENV=production bundle exec rails runner "t = TpcCode.new(tpc_number: 'TPC-TEST', tpc_name: 'Sample Title', tpc_owner_name: 'Jane', tpc_email: 'j@e.com'); puts t.valid?; puts t.display_name"`
Expected: `true` then a string containing `TPC-TEST - Sample Title - Jane`.

- [ ] **Step 8: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add db/migrate/032_add_name_to_tpc_codes.rb app/models/tpc_code.rb
git commit -m "feat(tpc): add optional tpc_name field with model, search, exports"
```

---

## Task 2: Controller params + TPC form/index/show views

**Files:**
- Modify: `app/controllers/tpc_codes_controller.rb:578`
- Modify: `app/views/tpc_codes/_form.html.erb`
- Modify: `app/views/tpc_codes/index.html.erb`
- Modify: `app/views/tpc_codes/show.html.erb`

**Interfaces:**
- Consumes: `TpcCode#tpc_name` from Task 1.
- Produces: `tpc_name` is now editable in the form, listed in the index table, shown on the show page.

- [ ] **Step 1: Permit `tpc_name` in strong params**

In `app/controllers/tpc_codes_controller.rb`, replace the permit line (line ~578):

```ruby
    params.require(:tpc_code).permit(:tpc_number, :tpc_name, :tpc_owner_name, :department, :tpc_email, :description, :is_active, :notes)
```

- [ ] **Step 2: Add TPC Name input to the form**

In `app/views/tpc_codes/_form.html.erb`, inside the first `pr-field-pair` (which holds `tpc_number` and `tpc_owner_name`), insert a TPC Name row. Replace that `pr-field-pair` block with a layout that keeps pairs balanced — put `tpc_name` next to `tpc_number`, and move `tpc_owner_name` to pair with `department`:

```erb
    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :tpc_number %> <span class="required">*</span>
        <%= f.text_field :tpc_number, required: true, maxlength: 50, class: 'form-control' %>
        <em class="info">Unique TPC number (e.g., TPC-2025-001)</em>
      </div>
      <div class="form-row">
        <%= f.label :tpc_name, 'TPC Name' %>
        <%= f.text_field :tpc_name, maxlength: 150, class: 'form-control' %>
        <em class="info">Descriptive title for this TPC (optional)</em>
      </div>
    </div>

    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :tpc_owner_name %> <span class="required">*</span>
        <%= f.text_field :tpc_owner_name, required: true, maxlength: 100, class: 'form-control' %>
        <em class="info">Full name of the TPC owner</em>
      </div>
      <div class="form-row">
        <%= f.label :department %>
        <%= f.text_field :department, maxlength: 100, class: 'form-control' %>
        <em class="info">Department name (optional)</em>
      </div>
    </div>

    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :tpc_email %> <span class="required">*</span>
        <%= f.email_field :tpc_email, required: true, maxlength: 255, class: 'form-control' %>
        <em class="info">Email address of the TPC owner</em>
      </div>
    </div>
```

(This replaces the original two `pr-field-pair` blocks that held tpc_number/owner and department/email.)

- [ ] **Step 3: Add Name column to the index table**

In `app/views/tpc_codes/index.html.erb`, add a header cell after `<th>TPC Number</th>` (line ~71):

```erb
          <th>TPC Name</th>
```

And add a body cell after the `owner-name`... no — after the TPC Number cell. Insert immediately after the `</td>` that closes the `tpc-number` cell (line ~94, before the `owner-name` td):

```erb
            <td class="tpc-name">
              <%= tpc_code.tpc_name.present? ? tpc_code.tpc_name : '-' %>
            </td>
```

- [ ] **Step 4: Add Name to the show page**

In `app/views/tpc_codes/show.html.erb`, in the details block, add a Name row immediately before the owner-name row (near line ~88). Match the existing `field`/`value` markup used by the owner row:

```erb
                <% if @tpc_code.tpc_name.present? %>
                  <div class="detail-field">
                    <span class="label">TPC Name</span>
                    <span class="value"><%= @tpc_code.tpc_name %></span>
                  </div>
                <% end %>
```

(Use the exact wrapper/class names already present around the adjacent owner-name/department rows — read lines 85–95 and mirror them; the label/value pattern above matches the `span.value` usage seen there.)

- [ ] **Step 5: Restart Redmine and verify in browser**

Run: `cd /opt/redmine && touch tmp/restart.txt` (or restart the app server used).
Then in the browser: open the global TPC codes index, create/edit a TPC code, set a TPC Name, save. Confirm the name shows in the form (edit), the index "TPC Name" column, and the show page.

- [ ] **Step 6: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add app/controllers/tpc_codes_controller.rb app/views/tpc_codes/_form.html.erb app/views/tpc_codes/index.html.erb app/views/tpc_codes/show.html.erb
git commit -m "feat(tpc): surface tpc_name in form, index, and show views"
```

---

## Task 3: Import/export doc + reports TPC name column

**Files:**
- Modify: `app/views/tpc_codes/import_export.html.erb`
- Modify: `lib/docx_report_helper.rb`

**Interfaces:**
- Consumes: CSV header `TPC Name` and importer support from Task 1.

- [ ] **Step 1: Update the import/export template docs**

In `app/views/tpc_codes/import_export.html.erb`:
- Line ~59 optional-fields list: add `TPC Name` to the optional fields, e.g. change to `<li><strong>Optional fields:</strong> TPC Name, Department, Description, Active Status, Notes...`.
- Line ~93 sample CSV template string: change the header/sample to include `tpc_name`:

```erb
                  URI.encode_www_form_component("tpc_number,tpc_name,tpc_owner_name,department,tpc_email,description,is_active,notes#{@project ? '' : ',project_name'}\nTPC-001,Network Infra 2026,John Doe,IT Department,john@example.com,Sample TPC Code,true,Sample notes#{@project ? '' : ',Demo Project'}"),
```

- If there is a nearby JSON sample object (around line ~103) that lists example keys, add `tpc_name: 'Network Infra 2026',` after the `tpc_number` key.

- [ ] **Step 2: Add TPC name to the DOCX report table**

In `lib/docx_report_helper.rb`, in `add_tpc_codes_section` (line ~271), extend the "Top TPC Codes by Cost" table with a Name column. Update the row mapping and the header:

```ruby
      rows = data[:utilization].first(20).map do |tpc|
        [tpc[:tpc_code].to_s, tpc[:tpc_name].to_s, tpc[:owner].to_s, tpc[:department].to_s,
         format_currency(tpc[:total_cost] || 0), tpc[:request_count].to_s]
      end
      add_simple_table(xml, 'Top TPC Codes by Cost',
                       ['TPC Code', 'TPC Name', 'Owner', 'Department', 'Total Cost', 'Requests'], rows)
```

Then find where `data[:utilization]` / the `:tpc_code` hash rows are built (in `reports_controller.rb` — grep for `tpc_code:` and `owner:`) and add `tpc_name: tpc.tpc_name,` to that hash so the report has the value. If the report builds from a `TpcCode` object, use `tpc.tpc_name`.

- [ ] **Step 3: Verify report source has the key**

Run: `cd /opt/redmine/plugins/redmine_purchase_requests && grep -n "tpc_name" reports_controller.rb app/controllers/reports_controller.rb lib/docx_report_helper.rb 2>/dev/null`
Expected: the `tpc_name:` key appears in both the report data builder and the docx helper.

- [ ] **Step 4: Manual verify export/import round-trip**

In the browser: export TPC codes to CSV; confirm the `TPC Name` column is present with values. Re-import the same CSV; confirm names are preserved (check a record's show page). Generate the TPC Codes DOCX report; confirm the TPC Name column appears.

- [ ] **Step 5: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add app/views/tpc_codes/import_export.html.erb lib/docx_report_helper.rb reports_controller.rb app/controllers/reports_controller.rb 2>/dev/null
git commit -m "feat(tpc): include tpc_name in import/export template and DOCX report"
```

---

## Task 4: TPC filter on CAPEX and OPEX dashboards

**Files:**
- Modify: `app/controllers/capex_controller.rb:94` (dashboard action)
- Modify: `app/views/capex/dashboard.html.erb:30-39`
- Modify: `app/controllers/opex_controller.rb:106` (dashboard action)
- Modify: `app/views/opex/dashboard.html.erb`

**Interfaces:**
- Produces: `@available_tpc_codes`, `@selected_tpc_code_id` for both dashboard views; both dashboards accept a `tpc_code_id` GET param combined with `year`.

- [ ] **Step 1: CAPEX controller — filter and dropdown data**

In `app/controllers/capex_controller.rb#dashboard`, right after `capex_for_year = @project.capex.for_year(@current_year)`, add:

```ruby
    @available_tpc_codes = TpcCode.available_for_project(@project).active.ordered
    @selected_tpc_code_id = params[:tpc_code_id].presence
    capex_for_year = capex_for_year.where(tpc_code_id: @selected_tpc_code_id) if @selected_tpc_code_id
```

(Because `@capex_entries`, totals, quarterly, currency, and TPC grouping all derive from `capex_for_year`, they inherit the filter automatically.)

- [ ] **Step 2: CAPEX view — add TPC select to the filter fieldset**

In `app/views/capex/dashboard.html.erb`, replace the `fieldset` (lines 31–38) with:

```erb
  <fieldset class="pr-filters">
    <legend>Filters</legend>
    <div class="filter-row">
      <%= select_tag 'year',
                     options_for_select((2020..2030).map { |y| [y, y] }, @current_year),
                     onchange: 'this.form.submit()' %>
      <%= select_tag 'tpc_code_id',
                     options_for_select([['All TPCs', '']] + @available_tpc_codes.map { |t| [t.display_name, t.id] }, @selected_tpc_code_id),
                     include_blank: false,
                     onchange: 'this.form.submit()' %>
    </div>
  </fieldset>
```

- [ ] **Step 3: OPEX controller — filter and dropdown data**

In `app/controllers/opex_controller.rb#dashboard`, right after `@opex_entries = @project.opex.for_year(@current_year)`, add:

```ruby
    @available_tpc_codes = TpcCode.available_for_project(@project).active.ordered
    @selected_tpc_code_id = params[:tpc_code_id].presence
    @opex_entries = @opex_entries.where(tpc_code_id: @selected_tpc_code_id) if @selected_tpc_code_id
```

- [ ] **Step 4: OPEX view — add TPC select**

In `app/views/opex/dashboard.html.erb`, find the year-filter `fieldset` (grep for `select_tag 'year'`) and add the same `select_tag 'tpc_code_id'` block shown in Step 2 immediately after the year select, inside the same `filter-row`.

- [ ] **Step 5: Restart and verify**

Run: `cd /opt/redmine && touch tmp/restart.txt`
Browser: open a project's CAPEX dashboard and OPEX dashboard. Confirm a TPC dropdown appears next to the year dropdown. Select a TPC — page reloads and all stats/charts reflect only that TPC. Confirm year + TPC combine (both persist after each change).

- [ ] **Step 6: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add app/controllers/capex_controller.rb app/views/capex/dashboard.html.erb app/controllers/opex_controller.rb app/views/opex/dashboard.html.erb
git commit -m "feat(dashboards): add TPC filter to CAPEX and OPEX dashboards"
```

---

## Task 5: TPC filter on Purchase Requests dashboard

**Files:**
- Modify: `app/controllers/purchase_requests_controller.rb:132` (dashboard action)
- Modify: `app/views/purchase_requests/dashboard.html.erb`

**Interfaces:**
- Consumes: filter pattern from Task 4.
- Produces: PR dashboard accepts `tpc_code_id` (direct linkage) + `year`.

- [ ] **Step 1: Controller — filter and dropdown data**

In `app/controllers/purchase_requests_controller.rb#dashboard`, after the year filter block (after the `if @selected_year.present?` `scope = scope.where(...)` lines), add:

```ruby
    tpc_scope = @project ? TpcCode.available_for_project(@project) : TpcCode
    @available_tpc_codes = tpc_scope.active.ordered
    @selected_tpc_code_id = params[:tpc_code_id].presence
    scope = scope.where(tpc_code_id: @selected_tpc_code_id) if @selected_tpc_code_id
```

(All counts and distributions derive from `scope`, so they inherit the filter.)

- [ ] **Step 2: View — add TPC select**

In `app/views/purchase_requests/dashboard.html.erb`, locate the year filter `form_tag`/`select_tag 'year'` (grep for `select_tag 'year'` or `'year'`) and add, inside the same form/filter-row, immediately after the year select:

```erb
      <%= select_tag 'tpc_code_id',
                     options_for_select([['All TPCs', '']] + @available_tpc_codes.map { |t| [t.display_name, t.id] }, @selected_tpc_code_id),
                     include_blank: false,
                     onchange: 'this.form.submit()' %>
```

If the year filter is not wrapped in a `pr-filters` fieldset here, wrap both selects in one `form_tag dashboard_project_purchase_requests_path(@project), method: :get` so they submit together. (Read the existing filter markup first and match it.)

- [ ] **Step 3: Restart and verify**

Run: `cd /opt/redmine && touch tmp/restart.txt`
Browser: open a project's Purchase Requests dashboard. Confirm the TPC dropdown appears. Select a TPC — totals, status/priority distributions reflect only PRs whose direct `tpc_code_id` matches. Confirm year + TPC combine.

- [ ] **Step 4: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add app/controllers/purchase_requests_controller.rb app/views/purchase_requests/dashboard.html.erb
git commit -m "feat(dashboards): add TPC filter to Purchase Requests dashboard"
```

---

## Task 6: TPC filter on the TPC dashboard

**Files:**
- Modify: `app/controllers/tpc_codes_controller.rb:246` (dashboard action)
- Modify: `app/views/tpc_codes/dashboard.html.erb`

**Interfaces:**
- Consumes: filter pattern from Task 4.
- Produces: TPC dashboard narrows to a single TPC when `tpc_code_id` is present, combined with `year`.

- [ ] **Step 1: Controller — dropdown data + single-TPC narrowing**

In `app/controllers/tpc_codes_controller.rb#dashboard`, after the block that sets `@all_tpc_codes`, `base_scope`, `pr_base_scope`, add:

```ruby
    @available_tpc_codes = (@project ? TpcCode.available_for_project(@project) : TpcCode).active.ordered
    @selected_tpc_code_id = params[:tpc_code_id].presence
    if @selected_tpc_code_id
      @all_tpc_codes = @all_tpc_codes.where(id: @selected_tpc_code_id)
      base_scope = base_scope.where(id: @selected_tpc_code_id)
    end
```

Then, so the purchase-request count charts also narrow: in each of the three count queries (`direct_tpc_counts`, `capex_tpc_counts`, `opex_tpc_counts`), add a matching filter when a TPC is selected. The simplest correct approach is to filter the resulting `tpc_pr_counts` hash — right after the three `.each` merges that populate `tpc_pr_counts`, add:

```ruby
    tpc_pr_counts.select! { |tpc_id, _| tpc_id.to_s == @selected_tpc_code_id } if @selected_tpc_code_id
```

- [ ] **Step 2: View — add TPC select**

In `app/views/tpc_codes/dashboard.html.erb`, locate the year filter (grep for `'year'`) and add, inside the same filter form/row, immediately after the year select:

```erb
      <%= select_tag 'tpc_code_id',
                     options_for_select([['All TPCs', '']] + @available_tpc_codes.map { |t| [t.display_name, t.id] }, @selected_tpc_code_id),
                     include_blank: false,
                     onchange: 'this.form.submit()' %>
```

Ensure both selects are inside one GET `form_tag tpc_codes_dashboard_path` (or the project-scoped dashboard path) so year + TPC submit together. Match the existing form markup.

- [ ] **Step 3: Restart and verify**

Run: `cd /opt/redmine && touch tmp/restart.txt`
Browser: open the TPC dashboard (global and within a project). Confirm the TPC dropdown appears. Select a TPC — the dashboard's listings and PR-count charts reflect only that TPC. Confirm year + TPC combine.

- [ ] **Step 4: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add app/controllers/tpc_codes_controller.rb app/views/tpc_codes/dashboard.html.erb
git commit -m "feat(dashboards): add TPC filter to the TPC dashboard"
```

---

## Task 7: TPC name in remaining TPC listings on the TPC dashboard

**Files:**
- Modify: `app/views/tpc_codes/dashboard.html.erb`

**Interfaces:**
- Consumes: `TpcCode#tpc_name` (Task 1).

- [ ] **Step 1: Add TPC name to any tabular TPC listing on the dashboard**

In `app/views/tpc_codes/dashboard.html.erb`, find any HTML table that lists TPC codes row-by-row (grep for `tpc_number` / `tpc.tpc_number` within `<td>`/`<th>`). For each such table, add a "TPC Name" header cell and a matching body cell rendering `tpc.tpc_name.present? ? tpc.tpc_name : '-'` (use the loop variable name actually present in that table). Do **not** alter chart axis labels (those intentionally use `tpc_number`).

If the dashboard contains no row-per-TPC HTML table (only charts), record that in the commit message and skip — no change needed.

- [ ] **Step 2: Restart and verify**

Run: `cd /opt/redmine && touch tmp/restart.txt`
Browser: open the TPC dashboard. Confirm any TPC listing table shows the name column; charts are unchanged.

- [ ] **Step 3: Commit**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add app/views/tpc_codes/dashboard.html.erb
git commit -m "feat(tpc): show tpc_name in TPC dashboard listings"
```

---

## Task 8: UI/UX review report

**Files:**
- Create: `docs/superpowers/specs/2026-08-02-uiux-review-findings.md`

**Interfaces:**
- Produces: a prioritized findings report for user approval; implementation of approved items is a **separate, later phase** (not in this plan).

- [ ] **Step 1: Audit the `pr-` design system across representative views**

Dispatch the `ux-designer` and `ui-designer` agents (in parallel) to review these representative views for a professional-yet-modern look: `app/views/purchase_requests/index.html.erb`, `.../show.html.erb`, `app/views/capex/dashboard.html.erb`, `app/views/tpc_codes/_form.html.erb`, `app/views/tpc_codes/index.html.erb`, a settings partial under `app/views/settings/`, and a report view. Also review the shared `pr-` CSS (grep for the stylesheet under `assets/stylesheets`). Each agent returns findings grouped by: visual hierarchy & typography; spacing/layout/grid; color/theming/contrast; component polish (tables, cards, filters, buttons, badges); cross-view consistency; responsiveness; accessibility.

- [ ] **Step 2: Synthesize into a prioritized report**

Write `docs/superpowers/specs/2026-08-02-uiux-review-findings.md` consolidating both agents' findings. Each finding tagged **severity (high/med/low) × effort (S/M/L)**, with a concrete before/after suggestion and the file(s) affected. End with a recommended implementation order (quick wins first).

- [ ] **Step 3: Commit and hand back for approval**

```bash
cd /opt/redmine/plugins/redmine_purchase_requests
git add docs/superpowers/specs/2026-08-02-uiux-review-findings.md
git commit -m "docs(uiux): prioritized UI/UX review findings report"
```

Then present the report to the user and ask which items to implement. Implementation of approved items is scoped in a follow-up plan.

---

## Self-Review Notes

- **Spec coverage:** Feature 2 (name) → Tasks 1–3, 7; Feature 1 (filters) → Tasks 4–6; Feature 3 (UI/UX) → Task 8. All spec surfaces covered (model, form, index, show, import/export, reports, dropdowns via display helpers, four dashboards).
- **Adaptation:** No test suite exists, so TDD test-file steps are replaced by `rails runner` sanity checks + manual browser verification, per Global Constraints. This is an intentional, documented deviation because the plugin has no test harness to hook into.
- **Type consistency:** `@available_tpc_codes`, `@selected_tpc_code_id`, and the `tpc_code_id` param name are used identically across Tasks 4–6. Display label uses `display_name` consistently.
- **Verification-before-completion:** every implementation task ends with an explicit restart + browser check before commit.
