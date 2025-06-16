# GROUP BY ORDER BY Fix Resolution Report

## Issue Description
The CAPEX dashboard was encountering a MySQL `sql_mode=only_full_group_by` error when trying to perform GROUP BY operations on relations that had ORDER BY clauses applied.

## Root Cause Analysis
The issue occurred in the `capex_controller.rb` dashboard method where we were:

1. Creating a base relation: `@capex_entries = @project.capex.for_year(@current_year).ordered`
2. Using this same relation for aggregation queries like: `@currency_breakdown = @project.capex.for_year(@current_year).group(:currency).sum(:total_amount)`

The problem was that the `ordered` scope adds `ORDER BY year, tpc_code` to the query, but when MySQL encounters a `GROUP BY :currency` operation, it requires that any columns in the ORDER BY clause must also be in the GROUP BY clause (when `sql_mode=only_full_group_by` is enabled).

## Error Details
```
ERROR: Expression #1 of ORDER BY clause is not in GROUP BY clause and contains nonaggregated column 'redmine.capex.tpc_code' which is not functionally dependent on columns in GROUP BY clause; this is incompatible with sql_mode=only_full_group_by
```

## Solution Applied
Modified the `dashboard` method in `/opt/redmine/plugins/redmine_purchase_requests/app/controllers/capex_controller.rb` to separate ordering from aggregation operations:

### Before (Problematic):
```ruby
def dashboard
  @current_year = params[:year].present? ? params[:year].to_i : Date.current.year
  @capex_entries = @project.capex.for_year(@current_year).ordered
  
  # Calculate summary statistics
  @total_budget = @capex_entries.sum(:total_amount)
  @total_utilized = @capex_entries.sum { |c| c.utilized_amount }
  # ... more calculations using @capex_entries
  
  # Currency breakdown
  @currency_breakdown = @project.capex.for_year(@current_year).group(:currency).sum(:total_amount)
```

### After (Fixed):
```ruby
def dashboard
  @current_year = params[:year].present? ? params[:year].to_i : Date.current.year
  # Get capex entries for the year without ordering for aggregations
  capex_for_year = @project.capex.for_year(@current_year)
  @capex_entries = capex_for_year.ordered
  
  # Calculate summary statistics using unordered relation
  @total_budget = capex_for_year.sum(:total_amount)
  @total_utilized = capex_for_year.sum { |c| c.utilized_amount }
  @total_remaining = @total_budget - @total_utilized
  @utilization_percentage = @total_budget > 0 ? (@total_utilized / @total_budget * 100).round(2) : 0
  
  # Quarterly breakdown using unordered relation
  @quarterly_data = {
    q1: capex_for_year.sum(:q1_amount),
    q2: capex_for_year.sum(:q2_amount),
    q3: capex_for_year.sum(:q3_amount),
    q4: capex_for_year.sum(:q4_amount)
  }
  
  # Currency breakdown using unordered relation
  @currency_breakdown = capex_for_year.group(:currency).sum(:total_amount)
```

## Key Changes Made
1. **Separated Base Relations**: Created `capex_for_year` as an unordered base relation
2. **Applied Ordering Only Where Needed**: Applied `.ordered` only to `@capex_entries` which is used for display
3. **Used Unordered Relations for Aggregations**: All `sum()` and `group()` operations now use the unordered `capex_for_year` relation

## Testing and Verification
- Created comprehensive test scripts to verify the fix
- Tested all dashboard aggregation queries
- Confirmed no MySQL GROUP BY errors occur
- Verified that ordering still works correctly for display purposes

## Files Modified
- `/opt/redmine/plugins/redmine_purchase_requests/app/controllers/capex_controller.rb`

## Resolution Status
✅ **RESOLVED** - The MySQL `sql_mode=only_full_group_by` error has been completely resolved.

The CAPEX dashboard now works correctly with proper separation of concerns between:
- **Ordering**: Applied only to display relations (`@capex_entries`)
- **Aggregation**: Uses unordered base relations for proper GROUP BY operations

## Impact
- CAPEX dashboard now loads without errors
- All budget calculations and currency breakdowns work correctly
- Proper data aggregation while maintaining display ordering
- No performance impact (same number of queries, just restructured)

This fix ensures MySQL compatibility while maintaining the intended functionality of the CAPEX dashboard.
