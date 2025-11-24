class PurchaseRequestSubtask < ActiveRecord::Base
  belongs_to :purchase_request
  belongs_to :issue
  belongs_to :workflow_template, class_name: 'PurchaseRequestWorkflowTemplate', optional: true

  validates :purchase_request, presence: true
  validates :issue, presence: true

  scope :sorted, -> { order(:position, :created_at) }

  delegate :subject, :status, :assigned_to, :done_ratio, to: :issue, allow_nil: true

  def completed?
    issue&.closed?
  end

  def status_name
    issue&.status&.name
  end

  def template_name
    workflow_template&.name || subtask_type
  end
end
