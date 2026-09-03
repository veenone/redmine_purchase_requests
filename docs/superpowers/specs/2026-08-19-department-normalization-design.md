# Department normalization

Extract the free-text `tpc_codes.department` string into a first-class
`departments` table carrying a code and a name.

## Why

`department` is a free-text column on `tpc_codes`, validated only for length.
Nothing prevents "R&D", "R & D" and "r&d" coexisting as three departments, and
there is no way to record a department code at all. Reporting and filtering on
department are unreliable as a result.

## Current state

Measured on the live instance:

- 9 TPC codes; 7 have a blank department, 2 carry `"R&D"`
- 1 distinct value, no case or whitespace collisions

The data migration is therefore small. The logic is still written to handle
collisions and blanks, because it will run against other instances.

## Blast radius

`department` is read in roughly 14 files, not just the model. Enumerated
before design, because three of these break in ways the column drop would not
make obvious.

**Model** (`tpc_code.rb`, 7 references) — length validation, search scope,
`tpc_number_with_description`, CSV export header and value, JSON export, CSV
import, JSON import.

**Aggregations that feed charts** — the ones that matter most:

- `reports_controller.rb:546` — `tpc_codes.where.not(department: [nil, '']).group(:department).count`
- `tpc_codes_controller.rb:318` — the same shape, building `@tpc_by_department`

Both must become `joins(:department).group('departments.name')`. Left alone
they raise on an unknown column, and the department distribution charts on the
TPC dashboard and TPC report go down with them.

**Sorting** — `c9257cf` made `department` a sortable column on the TPC index
(`tpc_codes_controller.rb:15` whitelist, `tpc_codes/index.html.erb:76`
header). After the drop, clicking that header emits `ORDER BY department`
against a table without the column. It must sort on the joined
`departments.name`, which requires the index scope to join departments.

**Writes** — `tpc_codes_controller.rb:606` permits `:department`; becomes
`:department_id`. `tpc_codes/_form.html.erb:44` is a free-text field; becomes
a select.

**Transitive readers** — `opex/index.html.erb:104` and
`purchase_requests/show.html.erb:327` both render `tpc_code.department`
directly and need `department&.name`.

**Other displays** — `tpc_codes/index.html.erb:105`, `tpc_codes/show.html.erb:96`,
`reports/tpc_codes.html.erb:286`, and the sample payloads in
`tpc_codes/import_export.html.erb`.

**Export** — `lib/docx_report_helper.rb:268` consumes
`data[:department_breakdown]` and `tpc[:department]`. Both are plain strings
supplied by the controller, so the helper needs no change provided the
controller keeps supplying department *names*.

## Decisions

| Question | Decision |
|---|---|
| Where DEP codes come from | Left blank by the migration; filled in through the UI |
| The old string column | Dropped, with a `down` that restores it |
| Scope | Global — one organisation-wide list, no per-project variants |
| Unmatched name on import | TPC imports with department unset, name reported in the import summary |

## Schema

```
departments
  id          bigint  primary key
  code        string(20)   null        -- blank until an admin fills it in
  name        string(100)  not null
  created_at, updated_at

  index on name, unique
  index on code, unique (nulls permitted)

tpc_codes
  + department_id  bigint null, indexed, FK -> departments.id (on delete: nullify)
  - department     string(100)                                  [dropped]
```

`name` is unique and required; `code` is unique when present but nullable,
because the migration cannot invent codes. Deleting a department nullifies the
link rather than destroying TPC codes.

No `is_active` flag. TpcCode has one, but nothing in the request needs
deactivatable departments, and it can be added later if it turns out to matter.

## Migrations

Two, not one. MySQL does not roll DDL back inside a transaction, so a single
migration that created a table, backfilled and dropped a column could fail
half-applied with no clean recovery.

**`038_create_departments.rb`** — creates the table only. Trivially
reversible.

**`039_link_tpc_codes_to_departments.rb`**

*up*
1. Add `department_id` to `tpc_codes`, indexed, with the foreign key.
2. Group existing non-blank `department` values by `name.strip.downcase`. For
   each group create one `Department`, taking the most frequent original
   spelling as the canonical `name` and leaving `code` blank.
3. Point each TPC code at its department.
4. Drop the `department` column.

*down*
1. Re-add `department` as `string(100)`.
2. Copy `departments.name` back into it through the association.
3. Remove `department_id` and the foreign key.

Rolling back therefore restores the original strings. It does not restore
codes, since none existed before the change.

## Model

`Department`
- `has_many :tpc_codes, dependent: :nullify`
- `validates :name`, presence and uniqueness (case-insensitive)
- `validates :code`, uniqueness when present, max length 20
- `scope :ordered`, by code then name
- `#display_name` → `"CODE - Name"`, or just the name while the code is blank

`TpcCode`
- `belongs_to :department, optional: true`
- The length validation on the old string is removed
- The search scope joins departments and searches `departments.name` and
  `departments.code` instead of the dropped column
- `tpc_number_with_description` reads `department&.name`

`display_name` is unaffected — it stopped including department in `2ac6036`.

### Sorting and aggregation

The TPC index scope gains `.left_joins(:department)` so that:

- the sort whitelist entry becomes `departments.name` in place of `department`
- TPC codes with no department still appear (an inner join would hide the 7
  rows that currently have none)

`@tpc_by_department` and the report's `department_breakdown` become
`joins(:department).group('departments.name').count`. An inner join is correct
there — both already exclude blanks, and the charts plot only real
departments.

## Import and export

Export gains a column rather than changing one, so existing consumers that read
`Department` keep working:

| CSV column | Source |
|---|---|
| `Department` | `department&.name` — unchanged header and meaning |
| `Department Code` | `department&.code` — new, trailing |

JSON export mirrors this with `department` and `department_code` keys.

Import matches on `Department` case-insensitively after stripping. When a name
does not match an existing department, the TPC code is imported with
`department_id` left null and the unmatched name is collected into the import
summary. Nothing is auto-created, so a typo cannot quietly add a department;
nothing hard-fails either, so existing CSV workflows keep running.

`Department Code`, when present, takes precedence over the name.

## CRUD

A `departments` section in the TPC settings tab
(`app/views/settings/_purchase_request_tpc.html.erb`), following the
`dashboard-card` pattern the tab already uses. A `DepartmentsController` with
the standard seven actions, permissions `view_departments` and
`manage_departments` registered in `init.rb`.

The TPC code form replaces its free-text department input with a select
populated from `Department.ordered`.

## Testing

`test/unit/department_test.rb` covers name presence, case-insensitive name
uniqueness, code uniqueness when present, two departments coexisting with blank
codes, and `display_name` with and without a code.

`test/unit/tpc_code_department_test.rb` covers the association, `dependent:
:nullify`, and the search scope matching on department name and code.

The migration's grouping logic is exercised directly against fixtures
representing `"R&D"`, `"r & d"` and `"  R&D  "` collapsing to one department.

Two further tests guard the failures this change makes easy to miss:

- the TPC index sorts on `departments.name` and still returns TPC codes with
  no department, which is what `left_joins` buys and an inner join would break
- `@tpc_by_department` and `department_breakdown` still produce
  `{name => count}` hashes, since `docx_report_helper` and the dashboard charts
  consume that shape directly

The rake harness remains blocked by `redmine_base_rspec` (unrelated, see
`redmine_customize_core_fields/init.rb:11`), so these are verified via
`rails runner` until it is fixed.

## Rollback

`rake redmine:plugins:migrate NAME=redmine_purchase_requests VERSION=37`
restores `tpc_codes.department` from the association and drops the table. The
live dataset is 2 rows carrying `"R&D"`, so the blast radius is small even if
the backfill misbehaves.

## Out of scope

Department on models other than `TpcCode`; per-project departments; department
filtering or reporting; backfilling codes. Sub-projects for the reports TPC
filter and XLSX export remain separate.
