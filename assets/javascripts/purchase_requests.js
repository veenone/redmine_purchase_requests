// This file contains JavaScript code related to the purchase requests functionality

$(document).ready(function() {
  // Tab functionality
  $('.tab-selector').click(function(e) {
    e.preventDefault();
    var tabId = $(this).data('tab');
    
    // Hide all tabbed forms
    $('.tabbed-form').hide();
    
    // Show the selected tab content
    $('#' + tabId).show();
    
    // Update tab selection
    $('.tabs ul li').removeClass('selected');
    $(this).parent('li').addClass('selected');
    
    return false;
  });
  
  // Initialize tab content - first tab is shown by default
  $('.tabbed-form').not('#tab-general').hide();
  
  // Vendor selection handling
  if ($('.vendor-select').length > 0) {
    // Initial setup - handle vendor dropdown
    $('.vendor-select').change(function() {
      var selectedVendorId = $(this).val();
      if (selectedVendorId) {
        loadVendorDetails(selectedVendorId);
      } else {
        hideVendorDetails();
      }
    });
    
    // Handle custom vendor checkbox if present
    $('.custom-vendor-checkbox').change(function() {
      if ($(this).is(':checked')) {
        $('.vendor-select').hide();
        $('.vendor-input').show().focus();
        hideVendorDetails();
      } else {
        $('.vendor-input').hide();
        $('.vendor-select').show();
        
        // If a vendor is selected, show its details
        var selectedVendorId = $('.vendor-select').val();
        if (selectedVendorId) {
          loadVendorDetails(selectedVendorId);
        }
      }
    });
    
    // Initial execution
    if ($('.custom-vendor-checkbox').length > 0 && $('.custom-vendor-checkbox').is(':checked')) {
      $('.vendor-select').hide();
      $('.vendor-input').show();
    } else {
      $('.vendor-input').hide();
      var selectedVendorId = $('.vendor-select').val();
      if (selectedVendorId) {
        loadVendorDetails(selectedVendorId);
      }
    }
  }
  
  function loadVendorDetails(vendorId) {
    // Get the base URL using the data attribute or construct it
    var baseUrl = $('.vendor-select').data('autocomplete-url') || 
                 (window.location.pathname.split('/').slice(0, -2).join('/') + '/vendors/autocomplete');
    
    $.ajax({
      url: baseUrl,
      data: { id: vendorId },
      dataType: 'json',
      success: function(data) {
        if (data) {
          // Update vendor details
          updateVendorDetails(data);
          $('.vendor-details').show();
        } else {
          hideVendorDetails();
        }
      },
      error: function() {
        hideVendorDetails();
      }
    });
  }
  
  function updateVendorDetails(vendor) {
    // Update all vendor details fields
    if (vendor.vendor_id) {
      $('#vendor-id-value').text(vendor.vendor_id);
      $('#vendor-id-row').show();
    } else {
      $('#vendor-id-row').hide();
    }
    
    if (vendor.address) {
      $('#vendor-address-value').text(vendor.address);
      $('#vendor-address-row').show();
    } else {
      $('#vendor-address-row').hide();
    }
    
    if (vendor.contact_person) {
      $('#vendor-contact-value').text(vendor.contact_person);
      $('#vendor-contact-row').show();
    } else {
      $('#vendor-contact-row').hide();
    }
    
    if (vendor.phone) {
      $('#vendor-phone-value').text(vendor.phone);
      $('#vendor-phone-row').show();
    } else {
      $('#vendor-phone-row').hide();
    }
    
    if (vendor.email) {
      $('#vendor-email-value').text(vendor.email);
      $('#vendor-email-row').show();
    } else {
      $('#vendor-email-row').hide();
    }
  }
  
  function hideVendorDetails() {
    $('.vendor-details').hide();
  }
});
/* ---------------------------------------------------------------------------
   Shared chart accessibility contract
   ---------------------------------------------------------------------------
   The Purchase Requests dashboard and the CAPEX/OPEX dashboards render charts
   with separate engines (different bar classes and heights, donut vs pie).
   Their *accessibility* behaviour, however, must not diverge again — the
   CAPEX charts were silent to assistive tech for exactly as long as the two
   copies existed. This is the single place that contract lives.

   prChartA11y(container, entries, opts)
     container - the chart element
     entries   - [{ label, display }] already-formatted for humans
     opts.empty     - true when there is nothing to plot
     opts.emptyText - what to say instead
     opts.scrollable- true if the container scrolls (adds a focus stop so
                      off-screen bars stay keyboard-reachable)
   -------------------------------------------------------------------------*/
function prChartA11y(container, entries, opts) {
  if (!container) return;
  opts = opts || {};
  var prefix = container.dataset && container.dataset.chartLabel
    ? container.dataset.chartLabel + ': '
    : '';

  container.setAttribute('role', 'img');

  if (opts.empty) {
    // An empty series is a real result, not an error. Say so, and never leave
    // a silent unlabelled box behind.
    container.setAttribute('aria-label', prefix + (opts.emptyText || 'No data'));
    container.classList.add('is-empty');
    container.removeAttribute('tabindex');
    var p = document.createElement('p');
    p.className = 'nodata';
    p.textContent = opts.emptyText || 'No data';
    container.appendChild(p);
    return;
  }

  container.classList.remove('is-empty');
  container.setAttribute('aria-label', prefix + entries.map(function (e) {
    return e.label + ' ' + e.display;
  }).join(', '));
  if (opts.scrollable) container.setAttribute('tabindex', '0');
}


/* ---------------------------------------------------------------------------
   Design-token reader for charts
   ---------------------------------------------------------------------------
   CSS custom properties are NOT substituted inside SVG presentation
   attributes — setAttribute('stroke', 'var(--pr-success)') yields an invalid
   value and the shape silently draws nothing. Read the token here and pass a
   real colour, so a chart can never drift from the stylesheet or vanish.
   -------------------------------------------------------------------------*/
function prToken(name, fallback) {
  var v = getComputedStyle(document.documentElement).getPropertyValue(name);
  return (v && v.trim()) || fallback;
}

/* ---------------------------------------------------------------------------
   Shared budget-dashboard charts (arc-path donut + quarterly bar chart)
   ---------------------------------------------------------------------------
   Originally written inline in capex/dashboard.html.erb and never shared —
   OPEX kept a separate stroke-dasharray donut that set `stroke` to a raw
   `var(--pr-success)` presentation attribute, which prToken() above exists
   specifically to avoid. Moved here, parameterized by `labels`, so both
   dashboards draw the one implementation that actually renders. `labels` is
   `{ utilized, remaining, overBudgetBy, noData }` — each dashboard supplies
   its own localised strings (see PR_CAPEX_LABELS / PR_OPEX_LABELS).
   -------------------------------------------------------------------------*/
function generateBudgetDonutChart(containerId, data, labels) {
  var container = document.getElementById(containerId);
  if (!container) return;

  var size = 140;
  var outerRadius = size / 2 - 10;
  var innerRadius = outerRadius * 0.6;
  var centerX = size / 2;
  var centerY = size / 2;

  var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('width', size);
  svg.setAttribute('height', size);
  svg.setAttribute('viewBox', '0 0 ' + size + ' ' + size);

  var total = data.utilized + data.remaining;
  // A zero total is only "no data" when nothing was committed either. Spend
  // against a zero budget also sums to zero here (utilized + -utilized), and
  // testing `total === 0` sent the most severe state this chart can show —
  // money spent with no budget behind it — down the empty-state path and drew
  // "No budget data" over it. Test both terms, so that case falls through to
  // the over-budget ring below.
  if (data.utilized === 0 && data.remaining === 0) {
    prChartA11y(container, [], { empty: true, emptyText: labels.noData });
    return;
  }

  prChartA11y(container, [
    { label: labels.utilized, display: data.utilized.toLocaleString() },
    // Sighted users read "Over budget by $5,000" under a red dot; the label
    // must tell the same story rather than announcing "Remaining -5000".
    { label: data.remaining < 0 ? labels.overBudgetBy : labels.remaining,
      display: Math.abs(data.remaining).toLocaleString() }
  ], {});

  // `total` is the budget (utilized + remaining), so at or above 100% the
  // utilized sweep reaches a full turn. An SVG arc whose endpoints coincide
  // paints nothing, and a negative remainder skips the second arc — which is
  // why the donut used to come out blank in exactly the over-budget state this
  // page exists to flag. Full circles are drawn as a circle, not an arc.
  var overBudget = data.remaining < 0;
  var utilizedPercentage = total > 0 ? data.utilized / total : 0;

  if (overBudget || utilizedPercentage >= 1) {
    var ringRadius = (outerRadius + innerRadius) / 2;
    var ring = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    ring.setAttribute('cx', centerX);
    ring.setAttribute('cy', centerY);
    ring.setAttribute('r', ringRadius);
    ring.setAttribute('fill', 'none');
    ring.setAttribute('stroke', overBudget
      ? prToken('--pr-danger', '#dc3a3a')
      : prToken('--pr-success', '#2f9e44'));
    ring.setAttribute('stroke-width', outerRadius - innerRadius);
    svg.appendChild(ring);
    // insertBefore, not appendChild: the centre label is already a child and
    // must stay in front of the ring (matches the normal path below).
    container.insertBefore(svg, container.firstChild);
    return;
  }

  var utilizedAngle = utilizedPercentage * 2 * Math.PI;

  if (utilizedPercentage > 0) {
    var path1 = prDonutPath(centerX, centerY, outerRadius, innerRadius, 0, utilizedAngle);
    var utilizedPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    utilizedPath.setAttribute('d', path1);
    utilizedPath.setAttribute('fill', prToken('--pr-success', '#2f9e44'));
    utilizedPath.setAttribute('stroke', prToken('--pr-surface', '#ffffff'));
    utilizedPath.setAttribute('stroke-width', '2');
    svg.appendChild(utilizedPath);
  }

  var remainingPercentage = data.remaining / total;
  if (remainingPercentage > 0) {
    var path2 = prDonutPath(centerX, centerY, outerRadius, innerRadius, utilizedAngle, 2 * Math.PI);
    var remainingPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    remainingPath.setAttribute('d', path2);
    remainingPath.setAttribute('fill', prToken('--pr-warning', '#df8709'));
    remainingPath.setAttribute('stroke', prToken('--pr-surface', '#ffffff'));
    remainingPath.setAttribute('stroke-width', '2');
    svg.appendChild(remainingPath);
  }

  container.insertBefore(svg, container.firstChild);
}

// Helper function to create donut path. Prefixed pr- to avoid shadowing (or
// being shadowed by) CAPEX's own identically-named inline helper — see the
// comment above generateBudgetDonutChart.
function prDonutPath(centerX, centerY, outerRadius, innerRadius, startAngle, endAngle) {
  var x1 = centerX + outerRadius * Math.cos(startAngle);
  var y1 = centerY + outerRadius * Math.sin(startAngle);
  var x2 = centerX + outerRadius * Math.cos(endAngle);
  var y2 = centerY + outerRadius * Math.sin(endAngle);

  var x3 = centerX + innerRadius * Math.cos(endAngle);
  var y3 = centerY + innerRadius * Math.sin(endAngle);
  var x4 = centerX + innerRadius * Math.cos(startAngle);
  var y4 = centerY + innerRadius * Math.sin(startAngle);

  var largeArcFlag = endAngle - startAngle > Math.PI ? 1 : 0;

  return [
    'M ' + x1 + ' ' + y1,
    'A ' + outerRadius + ' ' + outerRadius + ' 0 ' + largeArcFlag + ' 1 ' + x2 + ' ' + y2,
    'L ' + x3 + ' ' + y3,
    'A ' + innerRadius + ' ' + innerRadius + ' 0 ' + largeArcFlag + ' 0 ' + x4 + ' ' + y4,
    'Z'
  ].join(' ');
}

// Function to generate a quarterly bar chart
function generateBudgetBarChart(containerId, data, labels) {
  var container = document.getElementById(containerId);
  if (!container || !data.length) return;

  while (container.firstChild) {
    container.removeChild(container.firstChild);
  }

  var maxValue = Math.max.apply(null, data.map(function(item) { return item.value; }));
  if (maxValue === 0) {
    prChartA11y(container, [], { empty: true, emptyText: labels.noData });
    return;
  }

  prChartA11y(container, data.map(function (item) {
    return { label: item.label, display: item.value.toLocaleString() };
  }), { scrollable: true });

  data.forEach(function(item) {
    var barHeight = (item.value / maxValue) * 80;

    var bar = document.createElement('div');
    bar.className = 'capex-quarter-bar';
    bar.style.height = barHeight + 'px';

    var valueLabel = document.createElement('div');
    valueLabel.className = 'capex-quarter-value';
    valueLabel.textContent = item.value.toLocaleString();
    bar.appendChild(valueLabel);

    var quarterLabel = document.createElement('div');
    quarterLabel.className = 'capex-quarter-label';
    quarterLabel.textContent = item.label;
    bar.appendChild(quarterLabel);

    bar.title = item.label + ': ' + item.value.toLocaleString();

    container.appendChild(bar);
  });
}
