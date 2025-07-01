#!/bin/bash

echo "=== CAPEX Implementation Quick Validation ==="
echo "Date: $(date)"
echo

cd /opt/redmine/plugins/redmine_purchase_requests

echo "1. Checking file existence..."
files=(
    "app/controllers/capex_controller.rb"
    "app/helpers/capex_helper.rb"
    "app/views/capex/dashboard.html.erb"
    "app/views/settings/_purchase_request_capex.html.erb"
    "lib/settings_controller_patch.rb"
    "config/locales/en.yml"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file MISSING"
    fi
done

echo
echo "2. Checking Ruby syntax..."
ruby_files=(
    "app/controllers/capex_controller.rb"
    "app/helpers/capex_helper.rb"
    "lib/settings_controller_patch.rb"
)

for file in "${ruby_files[@]}"; do
    if [ -f "$file" ]; then
        if ruby -c "$file" >/dev/null 2>&1; then
            echo "  ✓ $file - syntax OK"
        else
            echo "  ✗ $file - syntax error"
        fi
    fi
done

echo
echo "3. Checking for ApexCharts removal..."
apexcharts_count=$(find app/views -name "*.erb" -exec grep -l "apexcharts\|ApexCharts" {} \; 2>/dev/null | wc -l)
if [ "$apexcharts_count" -eq 0 ]; then
    echo "  ✓ No ApexCharts dependencies found"
else
    echo "  ✗ ApexCharts still found in $apexcharts_count files"
fi

echo
echo "4. Checking dashboard features..."
if [ -f "app/views/capex/dashboard.html.erb" ]; then
    features=(
        "tpc_grouping:TPC Grouping"
        "@use_exchange_rates:Exchange Rate Support"
        "chart-container:Native Charts"
        "@current_year:Year Selection"
        "convert_capex_currency:Currency Conversion"
    )
    
    for feature in "${features[@]}"; do
        search_term="${feature%%:*}"
        feature_name="${feature#*:}"
        if grep -q "$search_term" "app/views/capex/dashboard.html.erb"; then
            echo "  ✓ $feature_name implementation found"
        else
            echo "  ✗ $feature_name implementation missing"
        fi
    done
fi

echo
echo "5. Checking Apache2 status..."
if systemctl is-active --quiet apache2; then
    echo "  ✓ Apache2 is running"
else
    echo "  ✗ Apache2 is not running"
fi

echo
echo "=== Validation Complete ==="
echo "Access your Redmine installation at: http://172.17.86.242/"
echo "Navigate to: Project → CAPEX → Dashboard to test the implementation"
echo
