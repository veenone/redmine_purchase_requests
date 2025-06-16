# Hook listener for redmine_purchase_requests plugin
module RedminePurchaseRequests
  class Hooks < Redmine::Hook::ViewListener
    # Use a more specific hook that only triggers for project pages
    render_on :view_projects_show_left, partial: 'hooks/purchase_requests/project_menu'
  end
end
