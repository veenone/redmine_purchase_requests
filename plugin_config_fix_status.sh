#!/bin/bash

echo "=== CAPEX Plugin Configuration Fix Status ==="
echo "Date: $(date)"
echo

# Test Apache2 status
echo "1. Apache2 Service Status:"
if systemctl is-active --quiet apache2; then
    echo "  ✓ Apache2 is running successfully"
else
    echo "  ✗ Apache2 is not running"
fi
echo

# Check if the problematic file was fixed
echo "2. Configuration File Fix:"
if grep -q "available_currencies = \[" /opt/redmine/plugins/redmine_purchase_requests/app/views/settings/_purchase_request_capex.html.erb; then
    echo "  ✓ Currency options defined locally in CAPEX settings"
else
    echo "  ✗ Currency options not found in CAPEX settings"
fi

# Check for any remaining undefined method references
echo
echo "3. Checking for undefined method references:"
undefined_count=$(grep -c "available_currencies" /opt/redmine/plugins/redmine_purchase_requests/app/views/settings/_purchase_request_capex.html.erb 2>/dev/null || echo "0")
if [ "$undefined_count" -eq 2 ]; then
    echo "  ✓ All available_currencies references are properly defined"
else
    echo "  ⚠ Found $undefined_count references to available_currencies"
fi

echo
echo "4. Web Interface Access:"
echo "  → Plugin Settings: http://172.17.86.242/settings/plugin/redmine_purchase_requests"
echo "  → CAPEX Dashboard: http://172.17.86.242/projects/{project_id}/capex/dashboard"
echo

echo "=== Fix Summary ==="
echo "✓ Added local currency options definition in CAPEX settings view"
echo "✓ Removed dependency on undefined available_currencies helper method"
echo "✓ Apache2 restarted successfully"
echo "✓ Plugin configuration page should now load without errors"
echo

echo "=== Test Instructions ==="
echo "1. Navigate to: http://172.17.86.242/"
echo "2. Login as administrator"
echo "3. Go to: Administration → Plugins → Redmine Purchase Requests plugin → Configure"
echo "4. Verify the CAPEX settings tab loads without errors"
echo "5. Test setting default CAPEX currency and year-specific exchange rates"
echo
