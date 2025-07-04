class Capex < ActiveRecord::Base
  self.table_name = 'capex'
  
  belongs_to :project
  belongs_to :tpc_code, optional: true
  belongs_to :opex_category, class_name: 'OpexCategory', foreign_key: 'category_id', optional: true
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
  validates :category_id, presence: true
  
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
  
  def display_name
    "#{tpc_code} - #{description} (#{year})"
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
    
    # If a TPC code object is selected, no need for legacy TPC code
    if tpc_code_id.present?
      # Clear legacy TPC code if TPC code is selected
      self.tpc_code = nil if tpc_code.present?
    else
      # If no TPC code selected, legacy TPC code is required (or optional based on settings)
      if require_tpc_for_capex || tpc_code.present?
        if tpc_code.blank?
          errors.add(:tpc_code, "can't be blank when no TPC code is selected")
        elsif tpc_code.length < 3 || tpc_code.length > 50
          errors.add(:tpc_code, "must be between 3 and 50 characters")
        end
      end
    end
  end
  
  def handle_tpc_code_assignment
    # If a TPC code ID is provided, clear the legacy TPC code
    if tpc_code_id.present?
      self.tpc_code = nil
    end
  end
end
