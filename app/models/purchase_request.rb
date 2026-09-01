class PurchaseRequest < ActiveRecord::Base
  # Ceiling used when no max_purchase_amount is configured. Matches the
  # precision 15, scale 2 estimated_price column, so the fallback never
  # permits a value the database cannot store.
  DEFAULT_MAX_PURCHASE_AMOUNT = BigDecimal('9999999999999.99')

  belongs_to :user
  belongs_to :project
  belongs_to :status, class_name: 'PurchaseRequestStatus', foreign_key: 'status_id'
  belongs_to :vendor, optional: true
  belongs_to :capex, optional: true
  belongs_to :opex, optional: true
  belongs_to :opex_category, class_name: 'OpexCategory', foreign_key: 'category_id', optional: true
  belongs_to :tpc_code, optional: true
  belongs_to :issue, optional: true

  LIFECYCLES = %w[active cancelled superseded].freeze

  belongs_to :revision_of, class_name: 'PurchaseRequest', optional: true
  belongs_to :cancelled_by, class_name: 'User', optional: true
  has_one :superseded_by, class_name: 'PurchaseRequest', foreign_key: 'revision_of_id'

  validates :lifecycle, inclusion: { in: LIFECYCLES }

  # Only active requests represent money anyone still intends to spend.
  scope :budgeted, -> { where(lifecycle: 'active') }

  def active?
    lifecycle == 'active'
  end

  def cancelled?
    lifecycle == 'cancelled'
  end

  def superseded?
    lifecycle == 'superseded'
  end

  def counts_toward_budget?
    active?
  end

  has_many :purchase_request_subtasks, dependent: :destroy
  has_many :subtask_issues, through: :purchase_request_subtasks, source: :issue
  
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
  validate :estimated_price_within_limit
  
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

  # Issue workflow methods
  def has_linked_issue?
    issue_id.present?
  end

  def workflow_enabled?
    Setting.plugin_redmine_purchase_requests['workflow_enabled'] == '1'
  end

  def create_workflow_issue!
    return if has_linked_issue?
    return unless workflow_enabled?
    return unless project.present?

    tracker_id = Setting.plugin_redmine_purchase_requests['workflow_tracker_id']
    return unless tracker_id.present?

    tracker = Tracker.find_by(id: tracker_id)
    return unless tracker.present?

    # Create main issue
    main_issue = Issue.new(
      project: project,
      tracker: tracker,
      author: user || User.current,
      subject: "PR-#{id}: #{title}",
      description: build_issue_description,
      priority: IssuePriority.default || IssuePriority.first,
      start_date: Date.current,
      due_date: due_date
    )

    if main_issue.save
      update_column(:issue_id, main_issue.id)
      create_workflow_subtasks!(main_issue)
      main_issue
    else
      Rails.logger.error "Failed to create workflow issue for PR##{id}: #{main_issue.errors.full_messages.join(', ')}"
      nil
    end
  end

  def create_workflow_subtasks!(parent_issue)
    templates = PurchaseRequestWorkflowTemplate.active.auto_create.sorted
    return if templates.empty?

    subtask_tracker_id = Setting.plugin_redmine_purchase_requests['workflow_subtask_tracker_id']
    subtask_tracker = Tracker.find_by(id: subtask_tracker_id) || parent_issue.tracker

    templates.each do |template|
      subtask = Issue.new(
        project: project,
        tracker: template.tracker || subtask_tracker,
        author: user || User.current,
        subject: "#{template.name} - PR-#{id}",
        description: template.description,
        priority: parent_issue.priority,
        parent_issue_id: parent_issue.id,
        assigned_to_id: template.default_assigned_to_id,
        estimated_hours: template.estimated_hours
      )

      if subtask.save
        purchase_request_subtasks.create!(
          issue: subtask,
          workflow_template: template,
          subtask_type: template.name,
          position: template.position
        )
      else
        Rails.logger.error "Failed to create subtask '#{template.name}' for PR##{id}: #{subtask.errors.full_messages.join(', ')}"
      end
    end
  end

  def workflow_progress
    return 0 unless has_linked_issue?
    return 0 if purchase_request_subtasks.empty?

    completed = purchase_request_subtasks.select(&:completed?).count
    total = purchase_request_subtasks.count
    ((completed.to_f / total) * 100).round
  end

  def all_subtasks_completed?
    return false if purchase_request_subtasks.empty?
    purchase_request_subtasks.all?(&:completed?)
  end

  def next_pending_subtask
    purchase_request_subtasks.sorted.find { |s| !s.completed? }
  end

  private

  def build_issue_description
    desc = []
    desc << "**Purchase Request Details**"
    desc << ""
    desc << "| Field | Value |"
    desc << "|-------|-------|"
    desc << "| PR ID | #{id} |"
    desc << "| Title | #{title} |"
    desc << "| Vendor | #{vendor_name} |"
    desc << "| Estimated Price | #{formatted_price} |"
    desc << "| Priority | #{priority&.capitalize} |"
    desc << "| Budget Source | #{budget_source} |"
    desc << "| TPC Code | #{tpc_code_display || 'N/A'} |"
    desc << ""
    desc << "**Description:**"
    desc << description if description.present?
    desc.join("\n")
  end

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

  # Caps estimated_price at the configured max_purchase_amount. Compared as
  # BigDecimal rather than Float so amounts near the column ceiling are not
  # thrown off by floating point rounding.
  def estimated_price_within_limit
    return if estimated_price.blank?

    configured = Setting.plugin_redmine_purchase_requests['max_purchase_amount'].to_s.to_d
    max = configured > 0 ? configured : DEFAULT_MAX_PURCHASE_AMOUNT

    if estimated_price > max
      errors.add(:estimated_price, :less_than, count: ActiveSupport::NumberHelper.number_to_delimited(max.to_s('F')))
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