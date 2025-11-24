# Issue hooks for purchase request workflow synchronization
module RedminePurchaseRequests
  class IssueHooks < Redmine::Hook::Listener
    # Called after an issue is saved
    def controller_issues_edit_after_save(context = {})
      issue = context[:issue]
      return unless issue

      sync_purchase_request_from_issue(issue)
    end

    # Called after bulk edit of issues
    def controller_issues_bulk_edit_after_save(context = {})
      issue = context[:issue]
      return unless issue

      sync_purchase_request_from_issue(issue)
    end

    private

    def sync_purchase_request_from_issue(issue)
      # Check if this issue is a main workflow issue for a purchase request
      purchase_request = PurchaseRequest.find_by(issue_id: issue.id)
      if purchase_request
        sync_main_issue_status(purchase_request, issue)
        return
      end

      # Check if this issue is a subtask of a purchase request workflow
      subtask_record = PurchaseRequestSubtask.find_by(issue_id: issue.id)
      if subtask_record
        update_parent_progress(subtask_record.purchase_request)
      end
    end

    def sync_main_issue_status(purchase_request, issue)
      # Update workflow progress when main issue changes
      update_parent_progress(purchase_request)

      # Optionally sync status based on issue status
      # This could be configured in plugin settings
      settings = Setting.plugin_redmine_purchase_requests || {}
      return unless settings['workflow_sync_status'] == '1'

      # Map issue status to purchase request status
      if issue.status.is_closed?
        # Find closed status for purchase request
        closed_status = PurchaseRequestStatus.where(is_closed: true).first
        if closed_status && purchase_request.status_id != closed_status.id
          purchase_request.update(status_id: closed_status.id)
        end
      end
    end

    def update_parent_progress(purchase_request)
      return unless purchase_request&.has_linked_issue?

      # Update main issue done_ratio based on subtask completion
      main_issue = purchase_request.issue
      return unless main_issue

      progress = purchase_request.workflow_progress

      # Only update if there's a meaningful change
      if main_issue.done_ratio != progress
        # Use update_column to avoid callbacks loop
        main_issue.update_column(:done_ratio, progress)
      end
    end
  end
end
