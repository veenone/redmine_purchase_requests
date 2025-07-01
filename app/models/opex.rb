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
