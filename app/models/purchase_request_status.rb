class PurchaseRequestStatus < ActiveRecord::Base
  has_many :purchase_requests

  validates :name, presence: true, uniqueness: true
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :color, presence: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: "must be a valid hex color" }

  # Ensure only one default status exists
  before_save :ensure_single_default
  
  # Add the sorted class method
  def self.sorted
    order(:position)
  end
  
  # Returns the default status for new purchase requests
  def self.default
    # First try to find a status marked as default
    default_status = where(is_default: true).first
    
    # If no default is set, use the first active status by position
    default_status || order(:position).first
  end
  
  private
  
  def ensure_single_default
    if is_default?
      # If this status is being set as default, unset all other defaults
      PurchaseRequestStatus.where.not(id: id).update_all(is_default: false)
    end
  end
end