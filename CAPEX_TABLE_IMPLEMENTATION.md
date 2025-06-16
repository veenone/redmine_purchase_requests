# CAPEX Exchange Rates - Table-Based Implementation

## Issue Resolved
The previous div-based year tab implementation was causing alignment issues with the year fields in the CAPEX exchange rates configuration.

## Solution: Table-Based Implementation
Replaced the div-based year tabs with a clean table-based layout similar to the currency settings tab.

## Changes Made

### 1. Replaced Year Tabs with Table Structure
**Before**: Separate year tabs with hidden/shown sections
**After**: Single table showing all years and currencies in organized rows

### 2. New Table Structure
```html
<table class="list capex-exchange-rates-table">
  <thead>
    <tr>
      <th class="year-column">Year</th>
      <th class="currency-column">Currency</th>
      <th class="rate-column">Rate to [Default Currency]</th>
      <th class="description-column">Description</th>
    </tr>
  </thead>
  <tbody>
    <!-- Year rows with rowspan for grouping -->
    <!-- Currency rows under each year -->
  </tbody>
</table>
```

### 3. Key Features
- **Year Column**: Uses `rowspan` to group currencies under each year
- **Proper Alignment**: Table structure ensures consistent column alignment
- **Responsive Design**: Clean table layout that works across all screen sizes
- **Consistent with Currency Settings**: Matches the existing currency settings table style

### 4. CSS Improvements
- Removed all div-based year tab styles
- Added table-specific styling for proper alignment
- Added hover effects and alternating row colors
- Year column highlighted with different background color
- Proper column widths for optimal layout

### 5. JavaScript Removed
- Eliminated the year tab switching JavaScript (no longer needed)
- Simpler implementation without client-side tab management

## Benefits

### ✅ **Fixed Alignment Issues**
- All years and currencies now properly aligned in columns
- No more mispositioned year fields

### ✅ **Better User Experience**
- All exchange rates visible at once (no tab switching required)
- Easier to compare rates across years
- More intuitive table layout

### ✅ **Consistent Design**
- Matches the currency settings tab design
- Uses standard Redmine table styling
- Professional appearance

### ✅ **Maintainable Code**
- Simpler implementation without JavaScript
- Standard table structure
- Easier to extend or modify

## File Modified
- `/opt/redmine/plugins/redmine_purchase_requests/app/views/settings/_purchase_request_capex.html.erb`

## Implementation Details

### Table Layout
- **Year Column**: Shows each year (2023-2028) with rowspan grouping
- **Currency Column**: Lists enabled currencies (excluding default currency)
- **Rate Column**: Input fields for exchange rates
- **Description Column**: Example conversion calculations

### Styling
- Consistent with Redmine's standard table styling
- Proper column widths and alignment
- Hover effects for better user interaction
- Year column highlighted for easy identification

## Result
The CAPEX exchange rates configuration now displays in a clean, properly aligned table format that matches the currency settings tab design and eliminates all alignment issues.

## Test Instructions
1. Navigate to: http://172.17.86.242/settings/plugin/redmine_purchase_requests
2. Click on the "CAPEX" tab
3. Scroll to "CAPEX Exchange Rates" section
4. Verify the table displays all years and currencies in properly aligned columns
5. Test entering exchange rates and saving the configuration
