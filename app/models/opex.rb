class Opex < ActiveRecord::Base
  self.table_name = 'opex'
  
  belongs_to :project
  belongs_to :opex_category, class_name: 'OpexCategory', foreign_key: 'category_id', optional: true
  has_many :purchase_requests, dependent: :nullify
  
  validates :year, presence: true, 
            numericality: { greater_than: 2000, less_than_or_equal_to: 2100 }
  validates :description, presence: true, length: { minimum: 3, maximum: 255 }
  validates :opex_code, presence: true, length: { minimum: 3, maximum: 50 }
  validates :total_amount, presence: true, 
            numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { 
    in: %w[USD EUR GBP JPY CAD AUD CHF CNY SEK NZD MXN SGD HKD IDR NOK KRW TRY RUB INR BRL ZAR] 
  }
  validates :q1_amount, :q2_amount, :q3_amount, :q4_amount, 
            presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :category_id, presence: true
  
  validate :quarterly_amounts_sum_equals_total
  validate :unique_opex_code_per_project_year
  
  scope :for_year, ->(year) { where(year: year) }
  scope :for_project, ->(project) { where(project: project) }
  scope :for_category, ->(category_id) { where(category_id: category_id) }
  scope :ordered, -> { order(:year, :opex_code) }
  scope :search, ->(term) { where("LOWER(description) LIKE ? OR LOWER(opex_code) LIKE ?", 
                                  "%#{term.to_s.downcase}%", "%#{term.to_s.downcase}%") }
  
  def total_quarterly_amount
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
    purchase_requests.where(opex: self).sum(:estimated_price) || 0
  end
  
  def remaining_amount
    total_amount - utilized_amount
  end
  
  def utilization_percentage
    return 0 if total_amount.zero?
    (utilized_amount / total_amount * 100).round(2)
  end
  
  def status_color
    case status
    when 'active' then '#28a745'
    when 'completed' then '#6c757d'
    when 'cancelled' then '#dc3545'
    when 'on_hold' then '#ffc107'
    else '#6c757d'
    end
  end
  
  def category_display
    opex_category&.name || 'Unknown'
  end
  
  def as_json(options = {})
    super(options.merge(
      methods: [:utilized_amount, :remaining_amount, :utilization_percentage, :total_quarterly_amount]
    ))
  end
  
  def currency_symbol
    case currency.to_s.upcase
    when 'USD' then '$'
    when 'EUR' then '€'
    when 'GBP' then '£'
    when 'JPY' then '¥'
    when 'CAD' then 'C$'
    when 'AUD' then 'A$'
    when 'CHF' then 'CHF'
    when 'CNY' then '¥'
    when 'SEK' then 'kr'
    when 'NOK' then 'kr'
    when 'DKK' then 'kr'
    when 'PLN' then 'zł'
    when 'CZK' then 'Kč'
    when 'HUF' then 'Ft'
    when 'RUB' then '₽'
    when 'BRL' then 'R$'
    when 'MXN' then '$'
    when 'INR' then '₹'
    when 'KRW' then '₩'
    when 'SGD' then 'S$'
    when 'HKD' then 'HK$'
    when 'NZD' then 'NZ$'
    when 'ZAR' then 'R'
    when 'TRY' then '₺'
    when 'ILS' then '₪'
    when 'AED' then 'د.إ'
    when 'SAR' then '﷼'
    when 'QAR' then 'ر.ق'
    when 'KWD' then 'د.ك'
    when 'BHD' then '.د.ب'
    when 'OMR' then 'ر.ع.'
    when 'JOD' then 'د.ا'
    when 'LBP' then 'ل.ل'
    when 'EGP' then 'ج.م'
    when 'MAD' then 'د.م.'
    when 'TND' then 'د.ت'
    when 'DZD' then 'د.ج'
    when 'LYD' then 'ل.د'
    when 'SDG' then 'ج.س.'
    when 'SOS' then 'Sh'
    when 'ETB' then 'Br'
    when 'KES' then 'Sh'
    when 'UGX' then 'Sh'
    when 'TZS' then 'Sh'
    when 'RWF' then 'Fr'
    when 'MWK' then 'MK'
    when 'ZMW' then 'ZK'
    when 'BWP' then 'P'
    when 'SZL' then 'L'
    when 'LSL' then 'L'
    when 'NAD' then '$'
    when 'MZN' then 'MT'
    when 'MGA' then 'Ar'
    when 'MUR' then '₨'
    when 'SCR' then '₨'
    when 'GMD' then 'D'
    when 'SLL' then 'Le'
    when 'LRD' then '$'
    when 'GHS' then '₵'
    when 'NGN' then '₦'
    when 'XOF' then 'Fr'
    when 'XAF' then 'Fr'
    when 'CVE' then '$'
    when 'STD' then 'Db'
    when 'AOA' then 'Kz'
    when 'CDF' then 'Fr'
    when 'BIF' then 'Fr'
    when 'DJF' then 'Fr'
    when 'ERN' then 'Nfk'
    when 'YER' then '﷼'
    when 'IQD' then 'ع.د'
    when 'IRR' then '﷼'
    when 'AFN' then '؋'
    when 'PKR' then '₨'
    when 'BDT' then '৳'
    when 'BTN' then 'Nu'
    when 'LKR' then '₨'
    when 'MVR' then '.ރ'
    when 'NPR' then '₨'
    when 'MMK' then 'Ks'
    when 'LAK' then '₭'
    when 'KHR' then '៛'
    when 'VND' then '₫'
    when 'THB' then '฿'
    when 'MYR' then 'RM'
    when 'BND' then '$'
    when 'IDR' then 'Rp'
    when 'PHP' then '₱'
    when 'TWD' then 'NT$'
    when 'MNT' then '₮'
    when 'KZT' then '₸'
    when 'KGS' then 'с'
    when 'UZS' then 'сўм'
    when 'TJS' then 'ЅМ'
    when 'TMT' then 'T'
    when 'AZN' then '₼'
    when 'GEL' then '₾'
    when 'AMD' then '֏'
    when 'BYN' then 'Br'
    when 'UAH' then '₴'
    when 'MDL' then 'L'
    when 'RON' then 'lei'
    when 'BGN' then 'лв'
    when 'RSD' then 'дин'
    when 'MKD' then 'ден'
    when 'ALL' then 'L'
    when 'BAM' then 'КМ'
    when 'HRK' then 'kn'
    when 'EUR' then '€'
    else '$'
    end
  end
  
  def display_name
    "#{opex_code} - #{description.truncate(50)}"
  end
  
  private
  
  def quarterly_amounts_sum_equals_total
    return unless q1_amount && q2_amount && q3_amount && q4_amount && total_amount
    
    sum = q1_amount + q2_amount + q3_amount + q4_amount
    if sum != total_amount
      errors.add(:base, "Quarterly amounts (#{sum}) must equal total amount (#{total_amount})")
    end
  end
  
  def unique_opex_code_per_project_year
    return unless opex_code && year && project_id
    
    existing = Opex.where(opex_code: opex_code, year: year, project_id: project_id)
    existing = existing.where.not(id: id) if persisted?
    
    if existing.exists?
      errors.add(:opex_code, "has already been taken for this project and year")
    end
  end
end
