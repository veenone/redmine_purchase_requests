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
