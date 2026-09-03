class Department < ActiveRecord::Base
  has_many :tpc_codes, dependent: :nullify

  before_validation { self.code = code.presence }

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { case_sensitive: false }
  validates :code, length: { maximum: 20 },
                   uniqueness: { case_sensitive: false },
                   allow_blank: true

  # Coded departments first, so the list an admin has curated sorts above the
  # ones still awaiting a code.
  scope :ordered, -> { order(Arel.sql("code IS NULL OR code = ''"), :code, :name) }

  def display_name
    code.present? ? "#{code} - #{name}" : name
  end
end
