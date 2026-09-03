# Purchase request revision and cancellation

Date: 2026-08-28
Status: approved, ready for an implementation plan

## The problem

A purchase request can only move forward. The six configured statuses run
Submitted → In progress → Need more info → On-hold → Under delivery →
Completed, and none of them ends a request unsuccessfully. When a supplier
changes a price, withdraws a quotation or reissues documents, there is no way
to stop the request or to replace it with a corrected one. The only options
are to edit it in place, losing what was previously agreed, or to abandon it
where it sits.

Two consequences follow.

**History is destroyed by correction.** Editing the price in place overwrites
the figure that was approved. The quotation attached to the request no longer
matches the number beside it, and nothing records that it ever did.

**Budget is consumed by work that will not happen.** `Capex#utilized_amount`
and `Opex#utilized_amount` sum every linked request and skip only those with
no price:

```ruby
purchase_requests.reject { |r| r.estimated_price.nil? }.sum { ... }
```

Status is not consulted at all. An abandoned request therefore holds budget
indefinitely, and adding a "Cancelled" status would not change that — nothing
reads status when computing spend.

## Decisions

Each was settled during design; the rationale matters more than the choice.

**A revision is a separate record, not a version of one record.** Revising
creates a new purchase request linked back to its predecessor. The old record
keeps its identity, attachments, comments and issue link, so the quotation
that was actually sent to a supplier remains readable against the figure it
justified.

**Lifecycle is a field of its own, not a status.** `status` continues to mean
how far a request progressed; `lifecycle` means whether it still counts. A
request cancelled during delivery keeps `Under delivery` as its status, which
is the fact worth preserving. The six existing statuses are untouched and need
no migration.

**Counts and money are different questions.** Cancelled and superseded
requests disappear from every figure representing committed spend, and remain
in every figure representing activity. "We raised 28 requests" stays true;
"we are committed to X" changes. Conflating the two would rewrite history to
make a budget total tidy.

**Documents do not follow a revision.** The superseded request keeps its
attachments; the new one starts empty and receives the new quotation. The
alternative — copying documents forward — produces two records claiming the
same document justifies two different prices.

## Data model

Six columns on `purchase_requests`:

| Column | Type | Notes |
| --- | --- | --- |
| `lifecycle` | string, not null, default `'active'` | `active` / `cancelled` / `superseded` |
| `revision_of_id` | integer, null, FK → `purchase_requests` | **unique index** |
| `revision_number` | integer, not null, default `1` | denormalised for display |
| `cancelled_at` | datetime, null | |
| `cancelled_by_id` | integer, null, FK → `users` | |
| `cancellation_reason` | text, null | required when cancelling |

**One back-pointer, not two.** `revision_of_id` points backward. "What
superseded this" is a lookup on that index rather than a second column, so the
two directions cannot disagree.

**The unique index is a correctness guard, not a nicety.** Without it, one
request could be revised twice, producing two active children that both
consume budget against a single intent — the failure most likely to corrupt
the figures this feature exists to protect. The database refuses it; no
controller check is relied upon.

**`revision_number` is denormalised deliberately.** It is derivable by walking
the chain, but a list view rendering "v3" per row would otherwise issue a
query per row. It is set once, at creation, as parent + 1.

### Lifecycle transitions

| From | Action | Result |
| --- | --- | --- |
| `active` | revise | parent → `superseded`; child created `active` |
| `active` | cancel | → `cancelled`, with who, when and why |
| `cancelled` | uncancel | → `active`, cancellation fields cleared |
| `superseded` | — | terminal; it already has a successor |

Revise and cancel act on active requests only. Cancel is reversible because a
mis-click would otherwise need direct SQL to undo. Uncancel is refused if
anything already supersedes the request.

A cancellation reason is required. A budget-affecting action with no stated
reason cannot be audited afterwards.

## Operations

### Revise

Runs in a single transaction: create the child, mark the parent superseded.
Either both happen or neither — a parent superseded with no child would delete
budget silently.

Copied to the child: title, description, project, vendor, TPC code, CAPEX or
OPEX link and category, allocated quarter, allocated amount, estimated price,
currency, priority, due date, product URL, notes, and `user_id`.

Not copied:

- **attachments** — the old quotation belongs to the version that used it
- **issue_id** — the Redmine issue belongs to the version that raised it
- **status** — resets to the default status, because the price changed and
  needs approving again; carrying `Under delivery` forward would skip that

`user_id` is copied rather than reassigned to whoever performed the revision:
the request still belongs to the person who raised it, and a revision corrects
it rather than transfers it.

### Cancel

Sets `lifecycle`, `cancelled_at`, `cancelled_by_id` and
`cancellation_reason`. `status` is left untouched, which is what preserves how
far the request got before it stopped.

### Uncancel

Clears the four cancellation fields and returns `lifecycle` to `active`.
Refused when a successor exists.

## Prerequisite: the test environment cannot currently boot

```
redmine_customize_core_fields plugin requires the redmine_base_rspec plugin
  (Redmine::PluginRequirementError)
```

`redmine_customize_core_fields` declares a test-only dependency on
`redmine_base_rspec`, which is not installed. The test environment therefore
fails during initialisation, and the plugin's six existing test files have
never run on this instance.

The first task installs `redmine_base_rspec`, satisfying the declaration.
Everything after it is test-driven; without it, nothing here can be verified
by a test at all. A `redmine_test` database is already configured and separate
from production, so the plugin dependency is the only obstacle.

## The budget rule

```ruby
def counts_toward_budget?
  lifecycle == 'active'
end
```

Completed requests still count: that money is committed. Only cancelled and
superseded requests stop.

### Thirty sites, one rule

An earlier count of twelve was taken from a truncated search. The real figure
is thirty:

| Location | Sites |
| --- | --- |
| `Capex#utilized_amount`, `Opex#utilized_amount` | 2 |
| `PurchaseRequestsController` — currency totals, monthly trends | 4 |
| `ReportsController` — value rollups, lines 279 to 2183 | 24 |

Thirty hand-edits, each individually plausible, is the shape of change where
one gets missed and two screens disagree about the same money without anyone
noticing. So the rule is stated once and called, rather than copied:

```ruby
# PurchaseRequest
scope :budgeted, -> { where(lifecycle: 'active') }

def self.committed_sum(scope = all)
  scope.budgeted.where.not(estimated_price: nil).sum(:estimated_price)
end
```

`ReportsController` repeats `.where.not(estimated_price: nil).sum(:estimated_price)`
two dozen times, several wrapped in `rescue 0`. Each becomes a
`PurchaseRequest.committed_sum(...)` call. A site missed during the sweep is
then a visible leftover of the old pattern rather than an invisible wrong
number, which is the difference between a bug you can grep for and one you
cannot.

The count sites are still left alone: total, open and closed counts, the
priority breakdown, monthly request counts, `TpcCode#purchase_requests.count`,
and the OPEX entries-table count.

Left alone, deliberately: total/open/closed counts, the priority breakdown,
monthly request counts, `TpcCode#purchase_requests.count`, and the OPEX
entries-table request count. These answer what was done, not what is owed.

### Two filtering techniques, not interchangeable

```ruby
# Capex/Opex: the association IS preloaded by the dashboard controller.
# Filter in Ruby.
purchase_requests.reject { |r| r.estimated_price.nil? || !r.counts_toward_budget? }

# Controllers and reports: plain scopes, not preloaded. Filter in SQL.
scope.where(lifecycle: 'active').where.not(estimated_price: nil).sum(:estimated_price)
```

A scoped `where` in the first case issues a fresh query even when the
association is preloaded, reintroducing the N+1 that `includes(:purchase_requests)`
was added to remove. A Ruby `reject` in the second loads every row into memory.
Both call sites carry a comment saying so, because the natural instinct is to
make them consistent with each other.

## Surfaces

**Request page.** A banner when the request is not active: "Superseded by
PR-31", or "Cancelled 28 Aug by A. Rahardianto — supplier withdrew quotation".
The revision chain is shown as v1 → v2 → v3, navigable in both directions.
Revise and Cancel appear only on active requests, and only with permission.

**CAPEX and OPEX detail pages.** Linked requests that no longer count render
struck through, annotated "does not count — superseded by PR-31". Without
this, a page listing five requests totalling 50,000 beside a utilised figure
of 35,000 reads as a defect. The annotation is what lets the list and the
total reconcile on sight.

**Request list.** Every lifecycle is listed by default; hiding superseded
requests would surprise someone searching for one. Superseded rows are muted
and link to their successor. A lifecycle filter sits beside the existing
status filter.

**Revision form.** Pre-filled from the parent, headed "Revision of PR-14",
with an empty attachments section.

**Cancel dialog.** Reason is a required field.

## Permissions

Two new project-scoped permissions inside the `purchase_requests` module:

- `:revise_purchase_requests`
- `:cancel_purchase_requests`

Both are separate from ordinary editing, so cancelling — which frees budget —
can be withheld from people who may otherwise edit a request. Uncancel is
governed by the cancel permission.

## Migration

The migration is inert. All existing requests take `lifecycle = 'active'`,
`revision_number = 1` and `revision_of_id = NULL` from the column defaults.
Nothing is transformed, and every budget figure on the day of deploy equals
the day before. The behaviour begins only when someone cancels or revises.

## Testing

Beyond the transitions themselves:

- **Revising twice is refused by the database.** The test asserts the unique
  constraint, not a controller guard, because the constraint is the guarantee.
- **The budget moves by exactly the right amount.** A CAPEX with three linked
  requests; cancel one; assert `utilized_amount` falls by that request's
  converted amount and `remaining_amount` rises to match. This is the
  requirement stated as an assertion.
- **The N+1 stays fixed.** Assert the query count while summing a CAPEX with
  many linked requests, so that rewriting the Ruby `reject` as a scoped
  `where` fails loudly rather than costing a query per row in silence.
- **Revise is atomic.** Force the child to fail validation; assert the parent
  is still active and no child exists.
- **Counts are unaffected.** Cancel a request; assert the report's total,
  open, closed and priority counts are unchanged while its value figures drop.

## Adjacent fix

`PurchaseRequestStatus has_many :purchase_requests` omits
`foreign_key: 'status_id'`, so it queries `purchase_request_status_id`, a
column that does not exist. Any code path calling `status.purchase_requests`
raises `Mysql2::Error`. It is one line, in the area this work touches, and is
fixed as part of it.

## Out of scope

- Approval workflow for revisions beyond resetting status to the default
- Notifying the requester or a manager when a request is cancelled
- Revising a cancelled request. Cancel is terminal; a later attempt is a new
  request. If this proves needed, allowing it is additive — the parent would
  stay `cancelled` while the child links through `revision_of_id`
- Making early statuses such as "Need more info" stop consuming budget. That
  is a separate question about when budget is reserved, and is worth asking
  once cancellation exists
- Reconciling the existing behaviour whereby every request consumes budget
  regardless of status. This design changes that only for cancelled and
  superseded requests

## Risks

**Thirty call sites is more than enough to miss one.** The
`committed_sum` helper is the mitigation: after the sweep, any surviving
`.where.not(estimated_price: nil).sum(:estimated_price)` is a missed site and
can be found with a single search. The plan lists every line, and the report
test covers the class of error.

**`ReportsController` is over 2,000 lines**, which is why the pattern was
copied so many times. Splitting it is out of scope here, but the helper at
least removes one reason to keep copying.

**The preload interaction is easy to undo.** The comment at each of the two
techniques is the mitigation; the query-count test is the backstop.

**`revision_number` can drift** if a chain is ever manipulated directly in the
database. It is display-only — no logic reads it — so drift is cosmetic.
