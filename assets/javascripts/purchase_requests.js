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
