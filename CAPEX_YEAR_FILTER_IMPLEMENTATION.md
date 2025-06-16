# CAPEX Exchange Rates - Year Filter Implementation

## Issues Resolved
1. **Year Column Not Populated**: Fixed the rowspan logic that was preventing year values from displaying properly
2. **No Year Filtering**: Added a dropdown filter to view exchange rates by specific year or all years

## New Features Added

### 1. Year Filter Dropdown
- **Location**: Above the exchange rates table
- **Options**: "All Years" + individual years (2023-2028)
- **Default**: Current year (2025) is pre-selected
- **Functionality**: Dynamically filters table rows based on selected year

### 2. Fixed Year Column Population
- **Before**: Year column used complex rowspan logic that often failed to display years correctly
- **After**: Each row now properly displays its corresponding year
- **Result**: Clear visibility of which year each exchange rate applies to

### 3. Enhanced Table Structure
- **Year Column**: Now populated for every row showing the specific year
- **Data Attributes**: Each row has `data-year` attribute for filtering
- **Row Classes**: Added `year-row` class for JavaScript targeting

## Implementation Details

### HTML Structure
```html
<!-- Year Filter -->
<div class="year-filter-container">
  <label for="capex_year_filter">Year:</label>
  <select id="capex_year_filter" class="year-filter-select">
    <option value="all">All Years</option>
    <option value="2023">2023</option>
    <!-- ... other years ... -->
  </select>
</div>

<!-- Table with proper year column -->
<table class="list capex-exchange-rates-table">
  <tr class="year-row" data-year="2025">
    <td class="year-column"><strong>2025</strong></td>
    <td class="currency-column">EUR</td>
    <!-- ... other columns ... -->
  </tr>
</table>
```

### JavaScript Functionality
- **Event Listener**: Responds to year filter dropdown changes
- **Row Filtering**: Shows/hides rows based on selected year
- **Row Striping**: Updates odd/even row classes after filtering
- **Default Selection**: Initializes with current year selected

### CSS Improvements
- **Filter Container**: Styled dropdown container with proper spacing
- **Filter Select**: Consistent styling with Redmine form elements
- **Hidden Rows**: CSS class to hide filtered rows
- **Year Column**: Enhanced styling for better visibility

## User Experience Improvements

### ✅ **Better Navigation**
- Users can quickly filter to view specific year's exchange rates
- "All Years" option provides complete overview when needed
- Current year is pre-selected for immediate relevance

### ✅ **Clear Data Display**
- Every row clearly shows which year the exchange rate applies to
- No more confusion about missing year information
- Consistent table structure across all rows

### ✅ **Efficient Management**
- Large datasets (6 years × multiple currencies) can be easily managed
- Quick switching between years for comparison
- Maintains form state when filtering

## Technical Benefits

### ✅ **Simplified Logic**
- Removed complex rowspan calculations
- Cleaner ERB template code
- More maintainable structure

### ✅ **Better Performance**
- Client-side filtering for instant response
- No server round-trips for filtering
- Efficient DOM manipulation

### ✅ **Enhanced Accessibility**
- Proper form labels for screen readers
- Keyboard navigation support
- Clear visual hierarchy

## Files Modified
- `/opt/redmine/plugins/redmine_purchase_requests/app/views/settings/_purchase_request_capex.html.erb`

## Testing Instructions
1. Navigate to: http://172.17.86.242/settings/plugin/redmine_purchase_requests
2. Click on the "CAPEX" tab
3. Scroll to "CAPEX Exchange Rates" section
4. **Test Year Filter**:
   - Verify dropdown shows "All Years" and years 2023-2028
   - Select different years and verify only those rows are displayed
   - Select "All Years" and verify all rows are shown
5. **Test Year Column**:
   - Verify each row clearly shows its year in the first column
   - Verify years are properly aligned and formatted
6. **Test Functionality**:
   - Enter exchange rates for different years
   - Verify filtering works correctly with entered data
   - Save settings and verify data persistence

## Result
The CAPEX exchange rates configuration now provides:
- ✅ **Proper year column population** - No more missing year information
- ✅ **Intuitive year filtering** - Easy navigation through large datasets
- ✅ **Better user experience** - Current year pre-selected for immediate use
- ✅ **Cleaner code structure** - More maintainable and reliable implementation
