module RedminePurchaseRequests
  # Feeds the project Files tab (app/views/files/index.html.erb override) the
  # purchase requests that carry attachments, one group per request, newest
  # first. Uses the sort_clause FilesController#index already set up, so the
  # files inside each group follow the column the reader sorted by.
  module FilesHelper
    def purchase_request_file_containers
      return [] unless @project.module_enabled?(:purchase_requests) &&
                       User.current.allowed_to?(:view_purchase_requests, @project)

      @project.purchase_requests
              .includes(:attachments).references(:attachments)
              .where.not(attachments: { id: nil })
              .reorder(sort_clause)
              .to_a
              .sort_by { |purchase_request| -purchase_request.id }
    end
  end
end
