class OpexCategory < ActiveRecord::Base
  self.table_name = 'opex_categories'
  has_many :opexes, foreign_key: 'category_id', dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true, length: { minimum: 2, maximum: 100 }
  default_scope { order(:position, :name) }
end
