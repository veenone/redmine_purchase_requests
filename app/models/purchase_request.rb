class PurchaseRequest < ActiveRecord::Base
  belongs_to :user
  belongs_to :status, class_name: 'PurchaseRequestStatus', foreign_key: 'status_id'
  belongs_to :vendor, optional: true
  belongs_to :capex, optional: true
  belongs_to :opex, optional: true
  belongs_to :opex_category, class_name: 'OpexCategory', foreign_key: 'category_id', optional: true
  
  # Include the attachable module from Redmine
  include Redmine::Acts::Attachable
  acts_as_attachable
  
  # For Rails 3.x/4.x compatibility
  if Redmine::VERSION::MAJOR < 5
    attr_accessible :title, :description, :status_id, :product_url, 
                   :estimated_price, :vendor, :vendor_id, :priority, :due_date, 
                   :notify_manager, :notes, :currency, :capex_id, :opex_id, :category_id
  end
  
  validates :title, presence: true, length: { minimum: 5, maximum: 255 }
  validates :description, length: { minimum: 10, allow_blank: true }
  validates :status_id, presence: true
  validates :estimated_price, numericality: { greater_than: 0, allow_blank: true }
  validates :product_url, format: { with: /\Ahttps?:\/\/.*\z/i, 
                                   allow_blank: true,
                                   message: :invalid_url }
  validates :due_date, comparison: { greater_than: Date.current, allow_blank: true }
  validates :currency, inclusion: { 
    in: %w[USD EUR GBP JPY CAD AUD CHF CNY SEK NZD MXN SGD HKD IDR NOK KRW TRY RUB INR BRL ZAR],
    allow_blank: true
  }
  validates :priority, inclusion: { in: %w[low normal high urgent] }
  # Note: category_id validation is handled in capex_or_opex_consistency method
  
  # Custom validations
  validate :vendor_presence_check
  validate :business_justification_for_high_value
  validate :capex_or_opex_consistency
  
  # Add any additional scopes or validations as needed
  scope :open, -> { joins(:status).where(purchase_request_statuses: { is_closed: false }) }
  scope :closed, -> { joins(:status).where(purchase_request_statuses: { is_closed: true }) }
  
  # Helper method to check if category_id column exists
  def self.has_category_id_column?
    column_names.include?('category_id')
  end
  
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
  def vendor_name
    vendor.present? ? vendor.name : read_attribute(:vendor)
  end
  
  # Enhanced priority handling
  def priority_color
    case priority
    when 'low' then '#28a745'
    when 'normal' then '#007bff'
    when 'high' then '#fd7e14'
    when 'urgent' then '#dc3545'
    else '#6c757d'
    end
  end
  
  def priority_icon
    case priority
    when 'low' then 'icon-arrow-down'
    when 'normal' then 'icon-arrow-right'
    when 'high' then 'icon-arrow-up'
    when 'urgent' then 'icon-warning'
    else 'icon-info'
    end
  end
  
  # Budget allocation methods
  def budget_source
    return "CAPEX: #{capex.description}" if capex.present?
    return "OPEX: #{opex.description}" if opex.present?
    "General Budget"
  end
  
  def is_high_value?
    estimated_price.present? && estimated_price > 1000
  end
  
  private
  
  def vendor_presence_check
    if vendor_id.blank? && read_attribute(:vendor).blank?
      errors.add(:base, I18n.t('error_vendor_required'))
    end
  end
  
  def business_justification_for_high_value
    if is_high_value? && (description.blank? || description.length < 50)
      errors.add(:description, I18n.t('error_business_justification_required'))
    end
  end
  
  def capex_or_opex_consistency
    if capex_id.present? && opex_id.present?
      errors.add(:base, I18n.t('error_cannot_link_both_capex_opex', default: 'Cannot link to both CAPEX and OPEX entries. Please select only one.'))
    end
    
    # Ensure category is selected only when OPEX is selected and category_id column exists
    if opex_id.present? && self.class.has_category_id_column? && category_id.blank?
      errors.add(:category_id, I18n.t('error_opex_category_required', default: 'OPEX category is required when OPEX is selected.'))
    end
  end
end