// CAPEX Management JavaScript
// Contains functionality for CAPEX forms, validation, and dashboard

$(document).ready(function() {
  // Initialize CAPEX functionality
  initializeCapexForm();
  initializeCapexTable();
});

// CAPEX Form Functionality
function initializeCapexForm() {
  // Quarterly amount validation
  $('.capex-quarterly-field input').on('input', function() {
    validateQuarterlyAmounts();
  });
  
  // Total amount change handler
  $('#capex_total_amount').on('input', function() {
    validateQuarterlyAmounts();
    updateAutoDistributeButton();
  });
  
  // Auto-distribute button
  $('.capex-auto-distribute button').on('click', function(e) {
    e.preventDefault();
    autoDistributeQuarterlyAmounts();
  });
  
  // Form submission validation
  $('#capex-form').on('submit', function(e) {
    if (!validateCapexForm()) {
      e.preventDefault();
      return false;
    }
  });
  
  // TPC Code validation
  $('#capex_tpc_code').on('blur', function() {
    validateTpcCode();
  });
  
  // Year validation
  $('#capex_year').on('blur', function() {
    validateYear();
  });
}

// Validate quarterly amounts sum to total
function validateQuarterlyAmounts() {
  var totalAmount = parseFloat($('#capex_total_amount').val()) || 0;
  var q1Amount = parseFloat($('#capex_q1_amount').val()) || 0;
  var q2Amount = parseFloat($('#capex_q2_amount').val()) || 0;
  var q3Amount = parseFloat($('#capex_q3_amount').val()) || 0;
  var q4Amount = parseFloat($('#capex_q4_amount').val()) || 0;
  
  var quarterlySum = q1Amount + q2Amount + q3Amount + q4Amount;
  var difference = Math.abs(totalAmount - quarterlySum);
  var isValid = difference < 0.01; // Allow for small floating point differences
  
  var validationDiv = $('.capex-total-validation');
  if (validationDiv.length === 0) {
    validationDiv = $('<div class="capex-total-validation"></div>');
    $('.capex-quarterly-grid').after(validationDiv);
  }
  
  if (totalAmount === 0) {
    validationDiv.hide();
  } else {
    validationDiv.show();
    
    if (isValid) {
      validationDiv.removeClass('invalid').addClass('valid');
      validationDiv.html('<i class="icon icon-ok"></i> Quarterly amounts sum correctly: ' + formatCurrency(quarterlySum));
    } else {
      validationDiv.removeClass('valid').addClass('invalid');
      validationDiv.html('<i class="icon icon-warning"></i> Quarterly sum (' + formatCurrency(quarterlySum) + ') does not match total (' + formatCurrency(totalAmount) + ')');
    }
  }
  
  return isValid;
}

// Auto-distribute total amount across quarters
function autoDistributeQuarterlyAmounts() {
  var totalAmount = parseFloat($('#capex_total_amount').val()) || 0;
  if (totalAmount <= 0) {
    alert('Please enter a valid total amount first');
    return;
  }
  
  var quarterlyAmount = (totalAmount / 4).toFixed(2);
  
  $('#capex_q1_amount').val(quarterlyAmount);
  $('#capex_q2_amount').val(quarterlyAmount);
  $('#capex_q3_amount').val(quarterlyAmount);
  $('#capex_q4_amount').val(quarterlyAmount);
  
  validateQuarterlyAmounts();
}

// Update auto-distribute button availability
function updateAutoDistributeButton() {
  var totalAmount = parseFloat($('#capex_total_amount').val()) || 0;
  var button = $('.capex-auto-distribute button');
  
  if (totalAmount > 0) {
    button.prop('disabled', false).text('Auto-distribute Quarterly');
  } else {
    button.prop('disabled', true).text('Enter total amount first');
  }
}

// Validate entire CAPEX form before submission
function validateCapexForm() {
  var isValid = true;
  var errors = [];
  
  // Check quarterly amounts
  if (!validateQuarterlyAmounts()) {
    errors.push('Quarterly amounts must sum to the total amount');
    isValid = false;
  }
  
  // Check year
  var year = parseInt($('#capex_year').val());
  if (!year || year < 2000 || year > 2100) {
    errors.push('Please enter a valid year between 2000 and 2100');
    isValid = false;
  }
  
  // Check TPC code
  var tpcCode = $('#capex_tpc_code').val();
  if (!tpcCode || tpcCode.trim() === '') {
    errors.push('TPC Code is required');
    isValid = false;
  }
  
  // Check total amount
  var totalAmount = parseFloat($('#capex_total_amount').val());
  if (!totalAmount || totalAmount <= 0) {
    errors.push('Total amount must be greater than zero');
    isValid = false;
  }
  
  // Display errors if any
  if (!isValid) {
    var errorHtml = '<div class="flash error"><ul>';
    errors.forEach(function(error) {
      errorHtml += '<li>' + error + '</li>';
    });
    errorHtml += '</ul></div>';
    
    $('.capex-form').prepend(errorHtml);
    $('html, body').animate({ scrollTop: 0 }, 300);
  }
  
  return isValid;
}

// Validate TPC Code uniqueness
function validateTpcCode() {
  var tpcCode = $('#capex_tpc_code').val();
  var year = $('#capex_year').val();
  var capexId = $('#capex_id').val(); // For edit mode
  
  if (!tpcCode || !year) return;
  
  // AJAX call to check TPC code uniqueness
  $.ajax({
    url: '/capex/validate_tpc_code',
    method: 'GET',
    data: {
      tpc_code: tpcCode,
      year: year,
      id: capexId
    },
    success: function(response) {
      if (!response.valid) {
        showFieldError('#capex_tpc_code', 'TPC Code already exists for this year');
      } else {
        clearFieldError('#capex_tpc_code');
      }
    }
  });
}

// Validate year
function validateYear() {
  var year = parseInt($('#capex_year').val());
  var currentYear = new Date().getFullYear();
  
  if (!year) {
    showFieldError('#capex_year', 'Year is required');
  } else if (year < currentYear - 5 || year > currentYear + 10) {
    showFieldError('#capex_year', 'Year should be within reasonable range');
  } else {
    clearFieldError('#capex_year');
  }
}

// Helper function to show field error
function showFieldError(fieldSelector, message) {
  clearFieldError(fieldSelector);
  $(fieldSelector).addClass('error');
  $(fieldSelector).after('<span class="error-message">' + message + '</span>');
}

// Helper function to clear field error
function clearFieldError(fieldSelector) {
  $(fieldSelector).removeClass('error');
  $(fieldSelector).next('.error-message').remove();
}

// Format currency for display
function formatCurrency(amount, currency) {
  currency = currency || 'USD';
  var formatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2
  });
  return formatter.format(amount);
}

// CAPEX Table Functionality
function initializeCapexTable() {
  if ($('.capex-table').length === 0) return;
  
  // Make table rows clickable
  $('.capex-table tbody tr').on('click', function() {
    var href = $(this).find('a').attr('href');
    if (href) {
      window.location = href;
    }
  });
  
  // Add hover effects
  $('.capex-table tbody tr').hover(
    function() { $(this).addClass('highlighted'); },
    function() { $(this).removeClass('highlighted'); }
  );
  
  // Initialize search functionality
  initializeCapexSearch();
}

// Initialize CAPEX search
function initializeCapexSearch() {
  $('#capex-search').on('input', function() {
    var searchTerm = $(this).val().toLowerCase();
    
    $('.capex-table tbody tr').each(function() {
      var rowText = $(this).text().toLowerCase();
      if (rowText.includes(searchTerm)) {
        $(this).show();
      } else {
        $(this).hide();
      }
    });
    
    updateTableVisibility();
  });
}

// Update table visibility based on search results
function updateTableVisibility() {
  var visibleRows = $('.capex-table tbody tr:visible').length;
  
  if (visibleRows === 0) {
    if ($('.no-results-message').length === 0) {
      $('.capex-table').after('<div class="no-results-message">No CAPEX entries match your search criteria.</div>');
    }
  } else {
    $('.no-results-message').remove();
  }
}

// Utility functions
function showCapexNotification(message, type) {
  type = type || 'info';
  var notification = $('<div class="capex-notification ' + type + '">' + message + '</div>');
  $('body').append(notification);
  
  setTimeout(function() {
    notification.fadeOut(function() {
      notification.remove();
    });
  }, 5000);
}

function confirmCapexAction(message, callback) {
  if (confirm(message)) {
    callback();
  }
}

// Export functions for global access
window.CapexManager = {
  validateQuarterlyAmounts: validateQuarterlyAmounts,
  autoDistributeQuarterlyAmounts: autoDistributeQuarterlyAmounts,
  showCapexNotification: showCapexNotification,
  confirmCapexAction: confirmCapexAction
};
