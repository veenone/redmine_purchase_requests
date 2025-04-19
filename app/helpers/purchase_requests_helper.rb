module PurchaseRequestsHelper
  def format_request_date(date)
    date.strftime("%B %d, %Y") if date
  end

  def request_status_label(status)
    case status
    when 'pending'
      content_tag(:span, status.humanize, class: 'label label-warning')
    when 'approved'
      content_tag(:span, status.humanize, class: 'label label-success')
    when 'rejected'
      content_tag(:span, status.humanize, class: 'label label-danger')
    else
      content_tag(:span, status.humanize, class: 'label label-default')
    end
  end

  def purchase_request_link(request)
    link_to(request.title, purchase_request_path(request))
  end
end