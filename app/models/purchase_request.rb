class PurchaseRequest < ActiveRecord::Base
  belongs_to :user
  belongs_to :status, class_name: 'PurchaseRequestStatus', foreign_key: 'status_id'
  belongs_to :vendor, optional: true
  belongs_to :capex, optional: true
  
  # Include the attachable module from Redmine
  include Redmine::Acts::Attachable
  acts_as_attachable
  
  # For Rails 3.x/4.x compatibility
  if Redmine::VERSION::MAJOR < 5
    attr_accessible :title, :description, :status_id, :product_url, 
                   :estimated_price, :vendor, :vendor_id, :priority, :due_date, 
                   :notify_manager, :notes, :currency, :capex_id
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
      symbol = PurchaseRequestsHelper.currency_symbol(currency || 'USD')
      "#{symbol}#{'%.2f' % estimated_price}"
    else
      "-"
    end
  end

  def currency
    read_attribute(:currency).presence || Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'
  end
  
  # Simplified workflow methods
  def open?
    !status.is_closed?
  end
  
  def closed?
    status.is_closed?
  end
  
  # Return the vendor name (for backward compatibility)
  def vendor
    if vendor_id.present? && (v = Vendor.find_by(id: vendor_id))
      v.name
    else
      read_attribute(:vendor)
    end
  end
  
  # Set the vendor by name or ID
  def vendor=(value)
    if value.is_a?(Integer) || value.to_i.to_s == value.to_s
      # It's an ID
      self.vendor_id = value
    else
      # It's a name
      write_attribute(:vendor, value)
      # Try to find a matching vendor
      v = Vendor.find_by(name: value)
      self.vendor_id = v.id if v
    end
  end
  
  # Method for checking if manager should be notified
  def notify_manager?
    notify_manager
  end
end