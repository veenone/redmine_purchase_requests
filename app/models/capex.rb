class Capex < ActiveRecord::Base
  self.table_name = 'capex'
  
  belongs_to :project
  belongs_to :tpc_code_record, class_name: 'TpcCode', foreign_key: 'tpc_code_id', optional: true
  has_many :purchase_requests, dependent: :nullify
  
  validates :year, presence: true, 
            numericality: { greater_than: 2000, less_than_or_equal_to: 2100 }
  validates :description, presence: true, length: { minimum: 3, maximum: 255 }
  validates :total_amount, presence: true, 
            numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { 
    in: %w[USD EUR GBP JPY CAD AUD CHF CNY SEK NZD MXN SGD HKD IDR NOK KRW TRY RUB INR BRL ZAR] 
  }
  validates :q1_amount, :q2_amount, :q3_amount, :q4_amount, 
            presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  validate :quarterly_amounts_sum_equals_total
  validate :unique_tpc_code_per_project_year
  validate :tpc_code_validation
  
  before_save :handle_tpc_code_assignment
  
  scope :for_year, ->(year) { where(year: year) }
  scope :for_project, ->(project) { where(project: project) }
  scope :ordered, -> { order(:year, :tpc_code) }
  scope :search, ->(term) { where("LOWER(description) LIKE ? OR LOWER(tpc_code) LIKE ?", 
                                  "%#{term.to_s.downcase}%", "%#{term.to_s.downcase}%") }
  
  def total_cashout_amount
    q1_amount + q2_amount + q3_amount + q4_amount
  end
  
  def quarterly_amounts
    [q1_amount, q2_amount, q3_amount, q4_amount]
  end
  
  def quarterly_percentage(quarter)
    return 0 if total_amount.zero?
    case quarter
    when 1 then (q1_amount / total_amount * 100).round(2)
    when 2 then (q2_amount / total_amount * 100).round(2)
    when 3 then (q3_amount / total_amount * 100).round(2)
    when 4 then (q4_amount / total_amount * 100).round(2)
    else 0
    end
  end
  
  def utilized_amount
    purchase_requests.where.not(estimated_price: nil).sum(:estimated_price)
  end
  
  def remaining_amount
    total_amount - utilized_amount
  end
  
  def utilization_percentage
    return 0 if total_amount.zero?
    (utilized_amount / total_amount * 100).round(2)
  end
  
  def tpc_code_display
    if tpc_code_id.present? && tpc_code_record.present?
      # Use the association to get the TPC code number (just the number for table display)
      tpc_code_record.tpc_number
    elsif tpc_code.present?
      # Use the legacy string field
      tpc_code
    else
      "No TPC Code"
    end
  end
  
  def display_name
    "#{tpc_code_display} - #{description} (#{year})"
  end
  
  def capex_year
    year
  end
  
  def currency_symbol
    case currency
    when 'USD' then '$'
    when 'EUR' then '€'
    when 'GBP' then '£'
    when 'JPY' then '¥'
    when 'CAD' then 'C$'
    when 'AUD' then 'A$'
    when 'CHF' then 'CHF'
    when 'CNY' then '¥'
    when 'SEK' then 'kr'
    when 'NZD' then 'NZ$'
    when 'MXN' then 'Mex$'
    when 'SGD' then 'S$'
    when 'HKD' then 'HK$'
    when 'IDR' then 'Rp'
    when 'NOK' then 'kr'
    when 'KRW' then '₩'
    when 'TRY' then '₺'
    when 'RUB' then '₽'
    when 'INR' then '₹'
    when 'BRL' then 'R$'
    when 'ZAR' then 'R'
    else currency
    end
  end

  def as_json(options = {})
    {
      id: id,
      project_id: project_id,
      year: year,
      description: description,
      tpc_code: tpc_code,
      total_amount: total_amount,
      currency: currency,
      currency_symbol: currency_symbol,
      q1_amount: q1_amount,
      q2_amount: q2_amount,
      q3_amount: q3_amount,
      q4_amount: q4_amount,
      utilized_amount: utilized_amount,
      remaining_amount: remaining_amount,
      utilization_percentage: utilization_percentage,
      notes: notes,
      display_name: display_name
    }
  end

  private
  
  def quarterly_amounts_sum_equals_total
    if total_amount.present? && (q1_amount + q2_amount + q3_amount + q4_amount) != total_amount
      errors.add(:base, "Sum of quarterly amounts must equal total amount")
    end
  end
  
  def unique_tpc_code_per_project_year
    if project && Capex.where(project: project, year: year, tpc_code: tpc_code)
                      .where.not(id: id).exists?
      errors.add(:tpc_code, "must be unique per project and year")
    end
  end
  
  def tpc_code_validation
    # Check if TPC code is required based on plugin settings
    require_tpc_for_capex = Setting.plugin_redmine_purchase_requests['tpc_require_for_capex'] == '1'
    
    # TPC code field is required by database constraint, so always validate it
    if tpc_code.blank?
      errors.add(:tpc_code, "can't be blank")
      return
    end
    
    # Additional length validation
    if tpc_code.length < 3 || tpc_code.length > 50
      errors.add(:tpc_code, "must be between 3 and 50 characters")
    end
    
    # If no TPC code ID is selected and TPC codes are required, ensure legacy TPC code is provided
    if tpc_code_id.blank? && require_tpc_for_capex && tpc_code.blank?
      errors.add(:base, "A TPC code must be selected or a legacy TPC code must be provided")
    end
  end
  
  def handle_tpc_code_assignment
    # If a TPC code ID is provided, use the TPC code number from the association
    if tpc_code_id.present?
      if tpc_code_record.present?
        # Use the TPC code number from the associated record
        self.tpc_code = tpc_code_record.tpc_number
      else
        # If TPC code ID is invalid, clear it and keep existing tpc_code
        self.tpc_code_id = nil
      end
    end
    
    # Ensure tpc_code is never blank (database constraint requires a value)
    if tpc_code.blank?
      # If both tpc_code and tpc_code_id are blank, this is an error condition
      # This should be caught by validation, but ensure we have a value for the database
      errors.add(:tpc_code, "cannot be blank") unless errors.any?
    end
  end
end
