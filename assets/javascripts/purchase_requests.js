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