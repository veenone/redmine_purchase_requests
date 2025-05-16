# Hook listener for redmine_purchase_requests plugin
module RedminePurchaseRequests
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_layouts_base_html_head, partial: 'hooks/purchase_requests/includes'
  end
end
