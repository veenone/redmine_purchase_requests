class PurchaseRequestMailer < Mailer
  def new_request_notification(user, purchase_request)
    @purchase_request = purchase_request
    @project = purchase_request.project
    @requester = purchase_request.user

    # Set Redmine headers
    redmine_headers 'Project' => @project.identifier,
                    'PurchaseRequest-Id' => @purchase_request.id

    mail(
      to: user,
      subject: "[#{@project.name}] New Purchase Request: #{@purchase_request.title}"
    )
  end
end