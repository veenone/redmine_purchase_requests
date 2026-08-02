# Design: TPC Dashboard Filters, TPC Name Field, and UI/UX Review

**Date:** 2026-08-02
**Plugin:** Redmine Purchase Requests (v1.8.1)
**Working dir:** `/opt/redmine/plugins/redmine_purchase_requests`

## Overview

Three related pieces of work, delivered in order:

1. **TPC Name field** — a new optional descriptive title on TPC codes, surfaced across all related tables/views.
2. **Filter by TPC number** on all four dashboards (CAPEX, OPEX, Purchase Requests, TPC).
3. **UI/UX review** — a prioritized professional/modern improvement report, then implementation of approved items.

Sequenced **Feature 2 → Feature 1 → Feature 3**, so the TPC name exists before dashboards reference it, and the UI/UX review reflects the post-change state.

## Decisions (confirmed with user)

- **TPC name** = a descriptive title for the TPC code itself (e.g. "Network Infrastructure 2026"), distinct from `tpc_number` and `tpc_owner_name` (the person).
- **Nullable / optional** — no backfill of existing rows.
- **Filter on all four dashboards**, combined with the existing year filter.
- **UI/UX**: report first, then implement approved items.
- **PR dashboard TPC filter** uses the PR's **direct** `tpc_code_id` only (not TPCs inherited via linked CAPEX/OPEX).

---

## Feature 2: TPC Name field

### Data model

- Migration `db/migrate/032_add_name_to_tpc_codes.rb`:
  - `add_column :tpc_codes, :tpc_name, :string, limit: 150, null: true`
  - Optional non-unique index on `tpc_name` (consistent with `department` index in migration 031). Include it.
- Existing table columns for reference: `tpc_number`, `tpc_owner_name`, `tpc_email`, `department`, `description`, `is_active`, `notes`, `project_id`.

### Model (`app/models/tpc_code.rb`)

- Add validation: `validates :tpc_name, length: { maximum: 150 }` (no presence — optional).
- Add `tpc_name` to the `search` scope's `LOWER(...) LIKE ?` clause.
- Update label helpers so every dropdown/label picks up the name automatically:
  - `display_name` — prefer `tpc_name` when present, e.g. `tpc_number - tpc_name` (fall back to current owner-based format when blank).
  - `tpc_number_with_description` — include `tpc_name` when present.
- Update `as_json` methods list only if a new derived method is added (not required).
- CSV export (`self.to_csv`): add `'TPC Name'` header and `tpc.tpc_name` cell (place after `TPC Number`).
- JSON export (`self.to_json_export`): add `tpc_name: tpc.tpc_name`.
- CSV import (`self.import_from_csv`): read `row['TPC Name']&.strip` into `tpc_name`.
- JSON import (`self.import_from_json`): read `tpc_data['tpc_name']&.strip` into `tpc_name`.

### Views / surfaces ("all related tables")

Each must show the TPC name where TPC data is presented:

- **TPC form** (`app/views/tpc_codes/_form.html.erb` or equivalent) — new "TPC Name" text input, placed after TPC Number.
- **TPC index** (`app/views/tpc_codes/index.html.erb` and global index) — new "Name" column.
- **TPC show** (`app/views/tpc_codes/show.html.erb` and global show) — new "Name" field.
- **TPC dashboard** (`app/views/tpc_codes/dashboard.html.erb`) — include name in any TPC listing table (the dashboard builds chart rows from `tpc.tpc_number`; add name to tabular listings, not necessarily chart axis labels).
- **Import/export view** (`app/views/tpc_codes/*import_export*`) — document/preview the new `TPC Name` column in the template.
- **Reports** — any report (HTML/PDF/DOCX via `reports_controller`, `lib/branded_report_pdf`, `lib/docx_report_helper`) that lists TPC codes gets a name column where a TPC table is rendered. Audit and add where present.
- **CAPEX/OPEX/PR TPC selector dropdowns** — these render via `display_name` / `tpc_number_with_description`, so they update automatically. Verify (grep) that they use those helpers rather than raw `tpc_number`.

### Controller

- Permit `tpc_name` in the TPC params (strong params in `tpc_codes_controller.rb`, both project-scoped and global create/update paths).

---

## Feature 1: Filter by TPC number on all four dashboards

### Shared UI pattern

Mirror the existing year filter (`app/views/capex/dashboard.html.erb` lines 30–39):
- Inside the existing `<fieldset class="pr-filters">`, add a second `select_tag 'tpc_code_id'` with a blank "All TPCs" first option and `options_from_collection_for_select(@available_tpc_codes, :id, :display_name, params[:tpc_code_id])` (or `options_for_select`), `onchange: 'this.form.submit()'`.
- Both selects share one `form_tag` so year + TPC submit together and each preserves the other.
- Each controller action populates `@available_tpc_codes = TpcCode.available_for_project(@project).active.ordered` (global scope: `TpcCode.active.ordered`).

### Per-dashboard controller changes

- **CAPEX** (`capex_controller#dashboard`): after building `capex_for_year`, apply `capex_for_year = capex_for_year.where(tpc_code_id: params[:tpc_code_id])` when `params[:tpc_code_id].present?`. All downstream aggregations derive from `capex_for_year`, so they inherit the filter. Set `@selected_tpc_code_id` for the view.
- **OPEX** (`opex_controller#dashboard`): same treatment on `@opex_entries` (apply the `where` before the `if @opex_entries.any?` aggregation block).
- **Purchase Requests** (`purchase_requests_controller#dashboard`): after the year filter, apply `scope = scope.where(tpc_code_id: params[:tpc_code_id])` when present (direct linkage only). All counts/distributions derive from `scope`.
- **TPC dashboard** (`tpc_codes_controller#dashboard`): when `params[:tpc_code_id].present?`, narrow `@all_tpc_codes` / `base_scope` to that single TPC and filter the PR-count scopes (`pr_year_scope` and the direct/CAPEX/OPEX count queries) to that `tpc_code_id`, so all charts/tables reflect the single selected TPC.

### Views

Add the TPC select to each dashboard's filter fieldset:
`app/views/capex/dashboard.html.erb`, `app/views/opex/dashboard.html.erb`, `app/views/purchase_requests/dashboard.html.erb`, `app/views/tpc_codes/dashboard.html.erb`.
(`_clean` / `_backup` dashboard variants are not live and are left untouched.)

---

## Feature 3: UI/UX professional-modern review

### Approach

Use the ux-designer and ui-designer agents plus frontend-design principles to audit the `pr-` design system across representative views: list, show, dashboard, form, settings, and report pages.

### Deliverable

A prioritized findings report at `docs/superpowers/specs/2026-08-02-uiux-review-findings.md`, each finding tagged **severity × effort**, grouped by:

- Visual hierarchy & typography
- Spacing, layout & grid consistency
- Color, theming & contrast
- Component polish (tables, cards, filters, buttons, badges)
- Cross-view consistency
- Responsiveness
- Accessibility (contrast, focus states, semantics)

Each finding includes a concrete before/after suggestion. User approves items; approved items are implemented in a final phase (kept scoped to the `pr-` design system, no unrelated refactoring).

---

## Verification

No automated test suite exists in this plugin, so verification is manual:

1. `rake redmine:plugins:migrate NAME=redmine_purchase_requests RAILS_ENV=production` (run migration 032).
2. Restart Redmine to reload Ruby/model changes.
3. Confirm TPC name renders in: TPC form, index, show, dashboard listings, and reports.
4. CSV/JSON export → import round-trip preserves `tpc_name`.
5. Each of the four dashboards filters correctly by TPC alone, by year alone, and by both combined.
6. Existing TPC records (with null `tpc_name`) still load and save without error.

## Out of scope

- Backfilling `tpc_name` on existing records.
- Making `tpc_name` required/unique.
- Reworking non-live dashboard variants (`_clean`, `_backup`).
- UI/UX changes beyond the approved report items.
