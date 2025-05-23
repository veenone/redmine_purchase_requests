class Vendor < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true
  
  # A vendor can have many purchase requests
  has_many :purchase_requests
  
  scope :sorted, -> { order(:name) }
  scope :search, ->(term) { where("LOWER(name) LIKE :term OR LOWER(vendor_id) LIKE :term", term: "%#{term.downcase}%") if term.present? }
  
  def to_s
    name
  end
  
  # Returns a hash of vendor attributes for JSON response
  def as_json(options = {})
    {
      id: id,
      name: name,
      vendor_id: vendor_id,
      address: address,
      phone: phone,
      contact_person: contact_person,
      email: email
    }
  end
  
  # Returns a formatted display name for the vendor
  def display_name
    if vendor_id.present?
      "#{name} (#{vendor_id})"
    else
      name
    end
  end
end
