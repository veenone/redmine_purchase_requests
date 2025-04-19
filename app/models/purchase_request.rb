class PurchaseRequest < ActiveRecord::Base
  belongs_to :user
  belongs_to :status, class_name: 'PurchaseRequestStatus', foreign_key: 'status_id'
  
  # Include the attachable module from Redmine
  include Redmine::Acts::Attachable
  acts_as_attachable
  
  # For Rails 3.x/4.x compatibility
  if Redmine::VERSION::MAJOR < 5
    attr_accessible :title, :description, :status_id, :product_url, 
                   :estimated_price, :vendor, :priority, :due_date, 
                   :notify_manager, :notes
  end
  
  validates :title, presence: true
  validates :status_id, presence: true
  validates :product_url, format: { with: /\Ahttps?:\/\/.*\z/i, 
                                   allow_blank: true,
                                   message: :invalid_url }
  
  # Add any additional scopes or validations as needed
  scope :open, -> { joins(:status).where(purchase_request_statuses: { is_closed: false }) }
  scope :closed, -> { joins(:status).where(purchase_request_statuses: { is_closed: true }) }
  
  def formatted_price
    if estimated_price.present?
      "$#{'%.2f' % estimated_price}"
    else
      "-"
    end
  end
  
  # Simplified workflow methods
  def open?
    !status.is_closed?
  end
  
  def closed?
    status.is_closed?
  end
  
  # Method for checking if manager should be notified
  def notify_manager?
    notify_manager
  end
end