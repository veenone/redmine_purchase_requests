# Shared Budget Dashboard — Design

**Date:** 2026-08-26
**Status:** Approved for planning
**Surfaces:** `app/views/capex/dashboard.html.erb`, `app/views/opex/dashboard.html.erb`

## Problem

CAPEX and OPEX are near-clone dashboards that have drifted apart under repeated
remediation. Six passes landed on CAPEX; OPEX received a subset of each, and in
two cases a fix applied to one twin actively contradicted the other.

Measured divergence: **516 of 1110 lines differ** after normalising the domain
words (`capex`/`opex`, `tpc_code`/`category`). That divergence is almost
entirely accumulated drift rather than domain difference — the two pages have
**identical section structure**:

1. Summary stat tiles (4)
2. Budget utilization donut
3. Quarterly distribution bars
4. Grouping section (TPC code / category)
5. Currency breakdown
6. Entries detail table

Controller state is near-identical too. OPEX declares every CAPEX ivar except
the three reliability ones — `@totals_unreliable`, `@currencies_mixed`,
`@unconvertible_currencies` — which is exactly the drift.

Concrete consequences found by critique, all traceable to "two copies":

- OPEX has no reliability model: a mixed-currency project prints a percentage
  derived from a sum of unlike units with no warning.
- Colour semantics inverted in two surviving places (`opex` category utilized
  tile is amber; `.remaining-budget` renders success green), against
  DESIGN.md's `green = utilized, amber = remaining, red = over`.
- OPEX had no over-budget state at all: permanent `pr-stat--warning`, raw
  negatives, permanent `status-remaining` legend dot.
- The OPEX donut rendered nothing for its entire life because it set `stroke`
  as an SVG presentation attribute to `var(--pr-success)`; CSS custom
  properties are not substituted there. CAPEX escaped only because it happened
  to have a local `prToken()`.
- Six strings remained hardcoded on OPEX after a "both dashboards" i18n pass.

## Goal

Make it structurally impossible for a fix to land on one budget dashboard and
miss the other, without forcing genuinely different content into one template.

**Non-goal:** changing what either dashboard *shows*, except where OPEX gains
behaviour CAPEX already has.

## Architecture

Three components, each with one responsibility.

### 1. `BudgetDashboard` concern

`app/controllers/concerns/budget_dashboard.rb`, included by `CapexController`
and `OpexController`. **The `app/controllers/concerns/` directory does not
exist in this plugin yet and is created by step 1.** Redmine plugins are
autoloaded from `app/`, so a concern there resolves without extra wiring —
step 1 must confirm that rather than assume it, since the plugin currently has
no precedent for one.

```ruby
budget_dashboard_figures(scope, model_class, year:, currency:)
  # => {
  #      total_budget:, total_utilized:, total_remaining:,
  #      utilization_percentage:,
  #      currencies_mixed:, unconvertible_currencies:, totals_unreliable:,
  #      over_budget:, severity:            # 'low' | 'medium' | 'high'
  #    }
```

Rules it owns, in one place:

- Currency conversion via the existing helpers; `utilized_amount` is already
  memoised per record and both dashboards preload `:purchase_requests`.
- `totals_unreliable` = (mixed currencies AND conversion off) OR any currency
  lacking a rate in all three lookup tables.
- `over_budget` = `!totals_unreliable && total_remaining < 0`. Severity is a
  conclusion; a conclusion drawn from unlike units is a false alarm.
- `severity` = `high` when over budget, `medium` at ≥80%, else `low`.

### 2. Shared shell

`app/views/shared/_budget_dashboard.html.erb`. Owns everything the two pages
legitimately share:

- reliability banner (using the plugin's standard `.pr-alert` icon +
  `.pr-alert-content` structure)
- four summary tiles, including the over-budget framing (label carries the
  direction, number carries the magnitude)
- utilization donut card, legend, and the unreliable-totals substitute content
- quarterly distribution card and its `<details>` data table
- currency breakdown card

Locals: `figures:`, `entries:`, `year:`, `currency_symbol:`,
`grouping_partial:`, `entries_partial:`, `labels:` (a small hash of the
model-specific strings: dashboard title, "by TPC code" / "by category",
new-entry path, etc.).

### 3. Per-model sections

Genuinely different content stays in its own file, rendered by the shell:

- `app/views/capex/_grouping.html.erb` / `app/views/opex/_grouping.html.erb`
- `app/views/capex/_entries_table.html.erb` / `app/views/opex/_entries_table.html.erb`

The grouping partials differ in dimension (TPC code vs category); the entries
tables differ in two columns (TPC Code vs OPEX Code + Category).

### Donut

The shell takes **one** implementation: CAPEX's arc-path renderer, which
already handles ≥100%, the over-budget ring, and `prToken()` colour
resolution. OPEX's stroke-dash ring is deleted rather than ported — it is the
implementation that never rendered.

`prToken()` and `prChartA11y()` already live in
`assets/javascripts/purchase_requests.js` and are used by both dashboards.

## Data flow

```
CapexController#dashboard
  include BudgetDashboard
  figures = budget_dashboard_figures(capex_for_year, Capex, year:, currency:)
  → render 'shared/budget_dashboard',
      figures:, entries: @capex_entries,
      grouping_partial: 'capex/grouping',
      entries_partial:  'capex/entries_table',
      labels: { ... }
```

`OpexController#dashboard` is the same call with `Opex` and its two partials.

## Rollout

Three separately committed, separately revertible steps. OPEX is last because
it is the only one whose output *should* change.

1. **Extract the concern.** Both controllers use it; both views unchanged.
   CAPEX and OPEX pages must render byte-identically.
2. **Build the shell from CAPEX's view.** CAPEX renders the shell; OPEX still
   renders its own view. CAPEX must render byte-identically.
3. **Point OPEX at the shell** with its two sub-partials. OPEX's output
   changes — and only in the intended directions.

## Verification

There is no automated test suite, so verification is an HTML-diff harness
rather than assertions.

**Before any change**, capture rendered HTML for both dashboards across
fixtures, using each controller's real computed assigns via `rails runner`:

| # | Fixture | Exercises |
|---|---|---|
| F1 | single currency, under budget | the ordinary path |
| F2 | single currency, over budget | over-budget framing, danger ring |
| F3 | exactly 100% utilization | the full-circle donut branch |
| F4 | mixed currency, conversion off | `totals_unreliable`, suppressed meter |
| F5 | conversion on, one currency lacking a rate | `unconvertible_currencies` badge |
| F6 | year with zero entries | empty state |
| F7 | zero CAPEX but non-zero OPEX (and the reverse) | asymmetric project state |

After each rollout step, re-render and diff:

- Steps 1 and 2: **CAPEX diff must be empty.** Any output is a defect.
- Step 3: OPEX diff must contain only intended additions. **The diff is shown
  to the reviewer, not summarised.**

Plus the standing checks used throughout this work: ERB compile on every
affected template, `ruby -c` on changed Ruby, `node --check` on inline scripts
and the shared asset, locale keys resolve, detector clean, `pr-*--modifier`
audit, and a line-ending audit before each commit.

## Out of scope

- TPC card wall → sortable table (separate design question: ranking by risk
  made a known code harder to find).
- Remaining N+1s on the `index` and `show` paths, and
  `quarterly_consumption`'s `.where` on the association.
- The Purchase Requests dashboard's pie charts lacking an empty state and
  `role="img"` on the zero path; `prChartA11y` remains at 2 of 3 callers.
- Merging the Purchase Requests dashboard into this shell. It is a different
  surface (request analytics, monthly buckets, comparison year), not a twin.

## Risks

- **Two live pages, no tests.** Mitigated by the HTML-diff harness and the
  staged rollout; a failure at any step is one revert.
- **Fixture coverage is the residual risk.** A rendering path not in F1–F7
  could change silently. The fixture list above is deliberately explicit so it
  can be challenged before implementation.
- **The shell's locals hash could become a dumping ground.** If it grows past
  roughly the fields listed, that is a signal the boundary is wrong and the
  section should become a slot instead.
