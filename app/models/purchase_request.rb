class PurchaseRequest < ActiveRecord::Base
  belongs_to :user
  belongs_to :project
  belongs_to :status, class_name: 'PurchaseRequestStatus', foreign_key: 'status_id'
  belongs_to :vendor, optional: true
  belongs_to :capex, optional: true
  belongs_to :opex, optional: true
  belongs_to :opex_category, class_name: 'OpexCategory', foreign_key: 'category_id', optional: true
  belongs_to :tpc_code, optional: true
  
  # Include the attachable module from Redmine
  include Redmine::Acts::Attachable
  acts_as_attachable
  
  # For Rails 3.x/4.x compatibility
  if Redmine::VERSION::MAJOR < 5
    attr_accessible :title, :description, :status_id, :product_url,
                   :estimated_price, :vendor, :vendor_id, :priority, :due_date,
                   :notify_manager, :notes, :currency, :capex_id, :opex_id, :category_id,
                   :project_id, :allocated_quarter, :allocated_amount, :tpc_code_id
  end
  
  validates :title, presence: true, length: { minimum: 5, maximum: 255 }
  validates :description, length: { minimum: 10, allow_blank: true }
  validates :status_id, presence: true
  validates :estimated_price, numericality: { greater_than: 0, allow_blank: true }
  validates :product_url, format: { with: /\Ahttps?:\/\/.*\z/i, 
                                   allow_blank: true }
  # Replace comparison validator with custom validation for Rails 6.1 compatibility
  validate :due_date_must_be_future
  validates :currency, inclusion: { 
    in: %w[USD EUR GBP JPY CAD AUD CHF CNY SEK NZD MXN SGD HKD IDR NOK KRW TRY RUB INR BRL ZAR],
    allow_blank: true
  }
  validates :priority, inclusion: { in: %w[low normal high urgent] }
  validates :allocated_quarter, inclusion: { in: [1, 2, 3, 4], allow_blank: true }
  validates :allocated_amount, numericality: { greater_than: 0, allow_blank: true }
  # Note: category_id validation is handled in capex_or_opex_consistency method
  
  # Custom validations
  validate :vendor_presence_check
  validate :business_justification_for_high_value
  validate :capex_or_opex_consistency
  validate :quarterly_allocation_consistency
  
  # Add any additional scopes or validations as needed
  scope :open, -> { joins(:status).where(purchase_request_statuses: { is_closed: false }) }
  scope :closed, -> { joins(:status).where(purchase_request_statuses: { is_closed: true }) }
  
  # Helper method to check if category_id column exists
  def self.has_category_id_column?
    column_names.include?('category_id')
  end
  
  def formatted_price(amount = nil)
    price = amount || estimated_price
    if price.present?
      symbol = PurchaseRequestsHelper.currency_symbol(currency || 'USD')
      "#{symbol}#{'%.2f' % price}"
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
  
  # Quarterly allocation methods
  def has_quarterly_allocation?
    allocated_quarter.present? && allocated_amount.present?
  end
  
  def quarter_name
    return nil unless allocated_quarter.present?
    "Q#{allocated_quarter}"
  end
  
  def allocation_impact_on_budget
    return {} unless has_quarterly_allocation? && (capex.present? || opex.present?)
    
    budget_entry = capex || opex
    quarter_field = "q#{allocated_quarter}_amount"
    original_quarter_amount = budget_entry.send(quarter_field)
    new_quarter_amount = original_quarter_amount - (allocated_amount || 0)
    
    {
      quarter: allocated_quarter,
      quarter_name: quarter_name,
      original_amount: original_quarter_amount,
      allocated_amount: allocated_amount,
      remaining_amount: new_quarter_amount,
      is_over_allocated: new_quarter_amount < 0
    }
  end
  
  def budget_entry
    capex || opex
  end
  
  def budget_type
    return 'capex' if capex.present?
    return 'opex' if opex.present?
    'none'
  end
  
  def has_budget_assignment?
    capex.present? || opex.present?
  end

  # TPC code display methods
  def tpc_code_display
    if tpc_code.present?
      tpc_code.tpc_number
    elsif capex.present? && capex.tpc_code_record.present?
      capex.tpc_code_display
    elsif opex.present? && opex.tpc_code.present?
      opex.tpc_code.tpc_number
    else
      nil
    end
  end

  def tpc_code_with_description
    if tpc_code.present?
      "#{tpc_code.tpc_number} - #{tpc_code.description}"
    elsif capex.present?
      capex.display_name
    elsif opex.present?
      opex.display_name
    else
      "No TPC Code"
    end
  end


  private
  
  # Custom validation for due_date to replace Rails 7 comparison validator
  def due_date_must_be_future
    return if due_date.blank?
    
    if due_date <= Date.current
      errors.add(:due_date, I18n.t('error_due_date_must_be_future', default: 'must be in the future'))
    end
  end
  
  def vendor_presence_check
    # Check if either vendor_id is present (for selected vendor) or vendor name is present (for custom vendor)
    has_selected_vendor = vendor_id.present? && vendor_id.to_i > 0
    has_custom_vendor = read_attribute(:vendor).present? && !read_attribute(:vendor).to_s.strip.empty?
    
    unless has_selected_vendor || has_custom_vendor
      errors.add(:vendor, I18n.t('error_vendor_required', default: 'Vendor is required. Please select a vendor or enter a custom vendor name.'))
    end
  end
  
  def business_justification_for_high_value
    if is_high_value? && (description.blank? || description.length < 50)
      errors.add(:description, I18n.t('error_business_justification_required', default: 'Business justification is required for high-value purchases. Please provide a detailed description (minimum 50 characters).'))
    end
  end
  
  def capex_or_opex_consistency
    if capex_id.present? && opex_id.present?
      errors.add(:base, I18n.t('error_cannot_link_both_capex_opex', default: 'Cannot link to both CAPEX and OPEX entries. Please select only one.'))
    end
    
    # Ensure category is selected only when OPEX is selected and category_id column exists
    if opex_id.present? && self.class.has_category_id_column? && category_id.blank?
      errors.add(:category_id, I18n.t('error_opex_category_required', default: 'OPEX category is required. Please select a category.'))
    end
  end
  
  def quarterly_allocation_consistency
    # If quarterly allocation is specified, ensure both quarter and amount are provided
    if allocated_quarter.present? && allocated_amount.blank?
      errors.add(:allocated_amount, I18n.t('error_allocated_amount_required', default: 'Allocated amount is required when specifying a quarter.'))
    end
    
    if allocated_amount.present? && allocated_quarter.blank?
      errors.add(:allocated_quarter, I18n.t('error_allocated_quarter_required', default: 'Quarter selection is required when specifying an allocated amount.'))
    end
    
    # If quarterly allocation is specified, ensure a budget entry (CAPEX or OPEX) is selected
    if has_quarterly_allocation? && capex_id.blank? && opex_id.blank?
      errors.add(:base, I18n.t('error_budget_required_for_allocation', default: 'A CAPEX or OPEX budget entry must be selected when specifying quarterly allocation.'))
    end
    
    # Validate allocation amount doesn't exceed estimated price
    if allocated_amount.present? && estimated_price.present? && allocated_amount > estimated_price
      errors.add(:allocated_amount, I18n.t('error_allocation_exceeds_price', default: 'Allocated amount cannot exceed the estimated price.'))
    end
  end
  
end