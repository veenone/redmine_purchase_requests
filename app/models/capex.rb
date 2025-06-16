class Capex < ActiveRecord::Base
  self.table_name = 'capex'
  
  belongs_to :project
  has_many :purchase_requests, dependent: :nullify
  
  validates :year, presence: true, 
            numericality: { greater_than: 2000, less_than_or_equal_to: 2100 }
  validates :description, presence: true, length: { minimum: 3, maximum: 255 }
  validates :tpc_code, presence: true, length: { minimum: 3, maximum: 50 }
  validates :total_amount, presence: true, 
            numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { 
    in: %w[USD EUR GBP JPY CAD AUD CHF CNY SEK NZD MXN SGD HKD IDR NOK KRW TRY RUB INR BRL ZAR] 
  }
  validates :q1_amount, :q2_amount, :q3_amount, :q4_amount, 
            presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  validate :quarterly_amounts_sum_equals_total
  validate :unique_tpc_code_per_project_year
  
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
end
