class Vendor < ActiveRecord::Base
  # Project relationship (if project_id column exists)
  belongs_to :project, optional: true
  
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :website, format: { with: URI.regexp(%w[http https]) }, allow_blank: true
  
  # Validate uniqueness of name within scope (global or project-specific)
  validates :name, uniqueness: { scope: :project_id }
  
  # A vendor can have many purchase requests
  has_many :purchase_requests
  
  scope :sorted, -> { order(:name) }
  scope :active, -> { where(is_active: true) }
  scope :global, -> { where('vendors.project_id' => nil) }
  scope :for_project, ->(project) { where('vendors.project_id' => project.id) if project }
  scope :available_for_project, ->(project) { 
    if project && column_names.include?('project_id')
      where("vendors.project_id IS NULL OR vendors.project_id = ?", project.id)
    else
      all
    end
  }
  scope :search, ->(term) { 
    where("LOWER(name) LIKE :term OR LOWER(vendor_id) LIKE :term OR LOWER(email) LIKE :term OR LOWER(contact_person) LIKE :term", 
          term: "%#{term.downcase}%") if term.present? 
  }
  
  def to_s
    name
  end
  
  # Check if vendor is global (not project-specific)
  def global?
    if self.class.column_names.include?('project_id')
      project_id.nil?
    else
      true  # All vendors are global if no project_id column
    end
  end
  
  # Check if vendor is project-specific
  def project_specific?
    !global?
  end
  
  # Get scope display text
  def scope_display
    global? ? 'GLOBAL' : 'PROJECT'
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
      email: email,
      website: website,
      notes: notes,
      is_active: is_active,
      project_id: project_id,
      scope: scope_display
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
