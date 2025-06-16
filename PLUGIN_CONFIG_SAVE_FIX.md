# Plugin Configuration Save Error Fix

## Issue
Error when saving plugin configuration:
```
RuntimeError (can't add a new key into hash during iteration)
plugins/redmine_purchase_requests/lib/settings_controller_patch.rb:31
```

## Root Cause
The `settings_controller_patch.rb` was trying to modify the `params[:settings]` hash while iterating over it with `.each`. This violates Ruby's hash iteration rules and causes a RuntimeError.

## Solution
Modified the `plugin_with_purchase_requests` method in `lib/settings_controller_patch.rb` to:

1. **Collect keys to delete during iteration** instead of deleting them immediately
2. **Store year-specific rates in a separate hash** to avoid modifying the hash being iterated
3. **Apply all changes after iteration is complete**

### Code Changes
- Added `keys_to_delete` array to collect keys that need to be removed
- Added `year_specific_rates` hash to store year-specific exchange rates
- Moved all hash modifications (adding/deleting keys) to after the iteration loop
- Removed the problematic `params[:settings].keys.each` loop that was modifying during iteration

## Fix Applied
✅ **File**: `/opt/redmine/plugins/redmine_purchase_requests/lib/settings_controller_patch.rb`
✅ **Apache2**: Restarted successfully
✅ **Status**: Ready for testing

## Test Instructions
1. Navigate to: http://172.17.86.242/settings/plugin/redmine_purchase_requests
2. Modify any CAPEX settings (currency, exchange rates, etc.)
3. Click "Apply" to save settings
4. Verify no errors occur and settings are saved successfully

## Resolution
The plugin configuration should now save without errors. Users can successfully:
- Configure default CAPEX currency
- Set year-specific exchange rates (2023-2028)
- Enable/disable CAPEX features
- Save all settings without RuntimeError exceptions
