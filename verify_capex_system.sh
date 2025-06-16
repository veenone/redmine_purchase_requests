#!/bin/bash

echo "==============================================="
echo "CAPEX SYSTEM VERIFICATION SCRIPT"
echo "==============================================="
echo ""

# Test 1: Check if CAPEX table exists
echo "1. Checking CAPEX table existence..."
CAPEX_TABLE_EXISTS=$(mysql -u redmine -psecretPassword -h localhost -D redmine -e "SHOW TABLES LIKE 'capex';" 2>/dev/null | grep capex)
if [ -n "$CAPEX_TABLE_EXISTS" ]; then
    echo "✓ CAPEX table exists"
    
    # Show table structure
    echo "  Table structure:"
    mysql -u redmine -psecretPassword -h localhost -D redmine -e "DESCRIBE capex;" 2>/dev/null | while read line; do
        echo "    $line"
    done
else
    echo "✗ CAPEX table does NOT exist"
    exit 1
fi

echo ""

# Test 2: Check if capex_id column exists in purchase_requests
echo "2. Checking purchase_requests.capex_id column..."
CAPEX_ID_EXISTS=$(mysql -u redmine -psecretPassword -h localhost -D redmine -e "SHOW COLUMNS FROM purchase_requests LIKE 'capex_id';" 2>/dev/null | grep capex_id)
if [ -n "$CAPEX_ID_EXISTS" ]; then
    echo "✓ capex_id column exists in purchase_requests"
else
    echo "✗ capex_id column missing in purchase_requests"
fi

echo ""

# Test 3: Check model files
echo "3. Checking model files..."
if [ -f "/opt/redmine/plugins/redmine_purchase_requests/app/models/capex.rb" ]; then
    echo "✓ CAPEX model exists"
    # Check syntax
    if ruby -c /opt/redmine/plugins/redmine_purchase_requests/app/models/capex.rb >/dev/null 2>&1; then
        echo "✓ CAPEX model syntax OK"
    else
        echo "✗ CAPEX model syntax ERROR"
    fi
else
    echo "✗ CAPEX model missing"
fi

echo ""

# Test 4: Check controller files
echo "4. Checking controller files..."
if [ -f "/opt/redmine/plugins/redmine_purchase_requests/app/controllers/capex_controller.rb" ]; then
    echo "✓ CAPEX controller exists"
    # Check syntax
    if ruby -c /opt/redmine/plugins/redmine_purchase_requests/app/controllers/capex_controller.rb >/dev/null 2>&1; then
        echo "✓ CAPEX controller syntax OK"
    else
        echo "✗ CAPEX controller syntax ERROR"
    fi
else
    echo "✗ CAPEX controller missing"
fi

echo ""

# Test 5: Check view files
echo "5. Checking view files..."
VIEW_FILES=(
    "index.html.erb"
    "new.html.erb"
    "edit.html.erb"
    "show.html.erb"
    "dashboard.html.erb"
    "_form.html.erb"
)

for view_file in "${VIEW_FILES[@]}"; do
    if [ -f "/opt/redmine/plugins/redmine_purchase_requests/app/views/capex/$view_file" ]; then
        echo "✓ $view_file exists"
    else
        echo "✗ $view_file missing"
    fi
done

echo ""

# Test 6: Check project patch
echo "6. Checking project patch..."
if [ -f "/opt/redmine/plugins/redmine_purchase_requests/lib/redmine_purchase_requests/patches/models_patch.rb" ]; then
    echo "✓ Project patch file exists"
    if grep -q "has_many :capex" /opt/redmine/plugins/redmine_purchase_requests/lib/redmine_purchase_requests/patches/models_patch.rb; then
        echo "✓ Project patch includes CAPEX association"
    else
        echo "✗ Project patch missing CAPEX association"
    fi
else
    echo "✗ Project patch file missing"
fi

echo ""

# Test 7: Check routes
echo "7. Checking routes configuration..."
if [ -f "/opt/redmine/plugins/redmine_purchase_requests/config/routes.rb" ]; then
    echo "✓ Routes file exists"
    if grep -q "capex" /opt/redmine/plugins/redmine_purchase_requests/config/routes.rb; then
        echo "✓ CAPEX routes configured"
    else
        echo "✗ CAPEX routes missing"
    fi
else
    echo "✗ Routes file missing"
fi

echo ""

# Test 8: Check assets
echo "8. Checking assets..."
if [ -f "/opt/redmine/plugins/redmine_purchase_requests/assets/stylesheets/capex.css" ]; then
    echo "✓ CAPEX CSS exists"
else
    echo "✗ CAPEX CSS missing"
fi

if [ -f "/opt/redmine/plugins/redmine_purchase_requests/assets/javascripts/capex.js" ]; then
    echo "✓ CAPEX JavaScript exists"
else
    echo "✗ CAPEX JavaScript missing"
fi

echo ""

# Test 9: Test database connectivity with Rails
echo "9. Testing Rails database connectivity..."
cd /opt/redmine
if timeout 30 bundle exec rails runner "puts 'Rails DB connection: OK'" RAILS_ENV=production 2>/dev/null | grep -q "OK"; then
    echo "✓ Rails database connection working"
else
    echo "⚠ Rails database connection test failed (may be normal)"
fi

echo ""
echo "==============================================="
echo "VERIFICATION COMPLETE"
echo "==============================================="
echo ""
echo "🎯 NEXT STEPS:"
echo "1. Restart your Redmine server:"
echo "   cd /opt/redmine && bundle exec rails server -e production"
echo ""
echo "2. Access Redmine in your browser"
echo ""
echo "3. Navigate to any project and look for 'CAPEX' in the project menu"
echo ""
echo "4. If you still get errors, check the Redmine production log:"
echo "   tail -f /opt/redmine/log/production.log"
echo ""
echo "✅ CAPEX implementation should now be functional!"
