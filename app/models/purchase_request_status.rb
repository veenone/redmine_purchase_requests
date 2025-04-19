class PurchaseRequestStatus < ActiveRecord::Base
  has_many :purchase_requests

  validates :name, presence: true, uniqueness: true

  # Add the sorted class method
  def self.sorted
    order(:position)  # Assuming there's a position column to sort by
    # or use another column like:
    # order(:name)
  end
  
  # Returns the default status for new purchase requests
  def self.default
    # First try to find a status marked as default
    default_status = where(is_default: true).first
    
    # If no default is set, use the first active status by position
    default_status || order(:position).first
  end
  
  # Define any additional status-related logic here
end