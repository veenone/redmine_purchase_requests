function initializeBudgetTracking() {
  // Handle CAPEX selection change
  $('#purchase_request_capex_id').on('change', function() {
    var capexId = $(this).val();
    var projectId = getProjectId();
    
    if (capexId && capexId !== '') {
      loadCapexDetails(projectId, capexId);
    } else {
      clearBudgetDetails();
    }
  });
}

function getProjectId() {
  // Try multiple ways to get project ID
  return $('#purchase_request_project_id').val() || 
         $('body').data('project-id') || 
         window.location.pathname.match(/projects\/(\d+)/)?.[1];
}

function loadCapexDetails(projectId, capexId) {
  $.ajax({
    url: '/projects/' + projectId + '/purchase_requests/load_capex_details',
    type: 'GET',
    data: { capex_id: capexId },
    dataType: 'json',
    success: function(response) {
      if (response.success && response.capex) {
        displayCapexDetails(response.capex);
      } else {
        console.error('Failed to load CAPEX details:', response.error);
      }
    },
    error: function(xhr, status, error) {
      console.error('CAPEX details load error:', error);
    }
  });
}

function displayCapexDetails(capex) {
  var detailsHtml = `
    <div class="budget-details">
      <h4>CAPEX Budget Details</h4>
      <table class="budget-info-table">
        <tr><td><strong>Year:</strong></td><td>${capex.year}</td></tr>
        <tr><td><strong>Description:</strong></td><td>${capex.description}</td></tr>
        <tr><td><strong>Total Budget:</strong></td><td>${capex.formatted_total}</td></tr>
        <tr><td><strong>Utilized:</strong></td><td>${capex.formatted_utilized}</td></tr>
        <tr><td><strong>Remaining:</strong></td><td style="color: ${capex.remaining_amount <= 0 ? 'red' : 'green'}">${capex.formatted_remaining}</td></tr>
        <tr><td><strong>Utilization:</strong></td><td>${capex.utilization_percentage}%</td></tr>
      </table>
    </div>
  `;
  
  // Find or create budget details container
  var container = $('#budget-details-container');
  if (container.length === 0) {
    $('#purchase_request_capex_id').closest('p').after('<div id="budget-details-container"></div>');
    container = $('#budget-details-container');
  }
  
  container.html(detailsHtml).show();
}

function clearBudgetDetails() {
  $('#budget-details-container').html('').hide();
}

// Initialize on document ready
$(document).ready(function() {
  initializeBudgetTracking();
});
