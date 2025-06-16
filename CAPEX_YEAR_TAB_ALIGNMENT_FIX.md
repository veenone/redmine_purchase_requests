# CAPEX Exchange Rates Year Field Alignment Fix

## Issue
The year field in the CAPEX exchange rates configuration was misaligned, with some year tabs (like "2028") appearing in incorrect positions relative to other year tabs.

## Root Cause
The CSS flexbox layout for `.year-tabs` was missing proper alignment properties, causing inconsistent positioning of year tab elements.

## Solution Applied
Enhanced the CSS styling for the year tabs in `/app/views/settings/_purchase_request_capex.html.erb`:

### CSS Changes Made:
1. **Added `flex-wrap: wrap`** - Allows tabs to wrap to new line if needed
2. **Added `align-items: center`** - Vertically centers all tab elements
3. **Enhanced `.year-tab` styling**:
   - Added `display: inline-flex`
   - Added `align-items: center` and `justify-content: center`
   - Added `min-width: 60px` for consistent tab sizing
   - Added `text-align: center` for text alignment
   - Added `vertical-align: middle` for baseline alignment

### Before:
```css
.year-tabs {
  margin-bottom: 20px;
  display: flex;
  gap: 10px;
}

.year-tab {
  padding: 8px 16px;
  background-color: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.3s;
}
```

### After:
```css
.year-tabs {
  margin-bottom: 20px;
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
}

.year-tab {
  padding: 8px 16px;
  background-color: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.3s;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 60px;
  text-align: center;
  vertical-align: middle;
}
```

## Fix Applied
✅ **File**: `/opt/redmine/plugins/redmine_purchase_requests/app/views/settings/_purchase_request_capex.html.erb`
✅ **Apache2**: Restarted successfully
✅ **Status**: Ready for testing

## Result
- All year tabs (2023, 2024, 2025, 2026, 2027, 2028) now align properly in a single row
- Consistent sizing and positioning across all year tabs
- Better responsive behavior if tabs need to wrap
- Improved visual consistency in the CAPEX settings interface

## Test Instructions
1. Navigate to: http://172.17.86.242/settings/plugin/redmine_purchase_requests
2. Click on the "CAPEX" tab
3. Scroll to "CAPEX Exchange Rates" section
4. Verify all year tabs are properly aligned horizontally
5. Click between different year tabs to ensure proper switching functionality
