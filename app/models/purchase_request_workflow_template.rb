class PurchaseRequestWorkflowTemplate < ActiveRecord::Base
  belongs_to :tracker, optional: true
  belongs_to :default_assigned_to, class_name: 'User', optional: true

  has_many :purchase_request_subtasks, foreign_key: :workflow_template_id, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(is_active: true) }
  scope :sorted, -> { order(:position, :name) }
  scope :auto_create, -> { where(auto_create: true) }

  # Default workflow templates
  DEFAULT_TEMPLATES = [
    { name: 'Vendor Registration', description: 'Register and verify vendor information', position: 1 },
    { name: 'PR Creation', description: 'Create and submit purchase request', position: 2 },
    { name: 'PO Creation', description: 'Create purchase order after approval', position: 3 },
    { name: 'Payment Finalization', description: 'Process payment and close request', position: 4 }
  ].freeze

  def self.create_defaults!
    DEFAULT_TEMPLATES.each do |template|
      find_or_create_by(name: template[:name]) do |t|
        t.description = template[:description]
        t.position = template[:position]
        t.is_active = true
        t.auto_create = true
      end
    end
  end

  def to_s
    name
  end
end
