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
  #
  # `entries` is enumerated in full (`.to_a` below) and `e.utilized_amount` is
  # called per record — for both CAPEX and OPEX that method walks the
  # `purchase_requests` association, so an un-preloaded relation here is an
  # N+1, not a SQL aggregate. Callers must pass a relation already carrying
  # `.includes(:purchase_requests)` (CAPEX: `@capex_entries`; OPEX:
  # `@opex_entries`) — never the raw un-preloaded scope some callers also
  # keep around for SQL-side `.sum(:column)`/`.group(...).sum(...)` calls,
  # since combining `.includes(has_many)` with those turns into a
  # LEFT OUTER JOIN that double-counts entries with 2+ linked requests.
  def budget_dashboard_figures(entries, currency:, convert:, missing_rate: nil)
    entries = entries.to_a

    total_budget   = entries.sum { |e| convert.call(e.total_amount    || 0, e.currency) }.round(2)
    total_utilized = entries.sum { |e| convert.call(e.utilized_amount || 0, e.currency) }.round(2)
    total_remaining = (total_budget - total_utilized).round(2)
    pct = total_budget > 0 ? ((total_utilized / total_budget) * 100).round(2) : 0

    # Blanks are a currency of their own for the mixed-units test — an entry
    # with no currency sitting beside an EUR entry is still two unlike units,
    # even though `presence` would drop the blank and read as "one currency".
    currencies_mixed = entries.map { |e| e.currency.to_s }.uniq.length > 1
    currencies = entries.map { |e| e.currency.presence }.compact.uniq
    unconvertible = missing_rate ? currencies.select { |c| missing_rate.call(c) } : []

    # Two ways a total can lie: it added unlike units, or a currency was passed
    # through unconverted because no rate exists.
    totals_unreliable = (currencies_mixed && missing_rate.nil?) || unconvertible.any?

    # Severity is a conclusion. A conclusion drawn from a sum of unlike units
    # is a false alarm, so it is suppressed rather than shown in red.
    over_budget = !totals_unreliable && total_remaining < 0

    # `pct` above is 0 whenever the denominator is 0, because it has to return
    # a number. Spend against an unset budget therefore reads as 0% utilised —
    # a green bar and no badge on the one condition this page exists to catch.
    # Flagged here so the views can render it as its own state. Suppressed when
    # totals are unreliable for the same reason over_budget is: it is a
    # conclusion, and a conclusion drawn from unlike units is a false alarm.
    budget_undefined = !totals_unreliable && total_budget <= 0 && total_utilized > 0

    {
      total_budget: total_budget,
      total_utilized: total_utilized,
      total_remaining: total_remaining,
      utilization_percentage: pct,
      currencies_mixed: currencies_mixed,
      unconvertible_currencies: unconvertible,
      totals_unreliable: totals_unreliable,
      over_budget: over_budget,
      budget_undefined: budget_undefined,
      # budget_undefined implies over_budget (remaining is -total_utilized), so
      # it is already 'high'. Named in the condition anyway: the two flags are
      # set independently and a later change to either must not silently
      # downgrade this one.
      severity: (over_budget || budget_undefined) ? 'high' : (pct >= 80 ? 'medium' : 'low')
    }
  end

  # Ranking key for the per-group card grid. Groups with spend against no
  # budget have an undefined ratio, so sorting on utilization_percentage alone
  # (which is 0 there) buries the most severe groups at the bottom of a
  # worst-first list.
  def budget_group_rank(data)
    [data[:budget_undefined] ? 0 : 1, -data[:utilization_percentage].to_f]
  end

  # Sortable columns for the entries table.
  #
  # Sorted in Ruby rather than SQL, and not by preference: utilized_amount,
  # remaining_amount and utilization_percentage are each computed by walking a
  # record's linked purchase requests and converting them, so there is no
  # column to ORDER BY. Pushing the sort into the relation would also re-issue
  # the query and defeat the `.includes(:purchase_requests)` preload the
  # figures depend on. The rows are already materialised by then, so this costs
  # an array sort.
  BUDGET_SORT_KEYS = {
    'budget'    => ->(e) { e.total_amount.to_f },
    'utilized'  => ->(e) { e.utilized_amount.to_f },
    'remaining' => ->(e) { e.remaining_amount.to_f },
    # An undefined ratio is not a low one. Budget-less spend sorts as the most
    # utilized, matching how budget_group_rank ranks it in the card grid.
    'utilization' => ->(e) { e.budget_undefined? ? Float::INFINITY : e.utilization_percentage.to_f }
  }.freeze

  # Unknown or absent sort key returns the rows in their existing order, so a
  # hand-edited or stale URL degrades to the default view rather than 500ing.
  def budget_dashboard_sort(entries, sort_key, direction)
    rows = entries.to_a
    key = BUDGET_SORT_KEYS[sort_key.to_s]
    return rows unless key

    rows = rows.sort_by { |e| key.call(e) }
    direction.to_s == 'asc' ? rows : rows.reverse
  end
end
