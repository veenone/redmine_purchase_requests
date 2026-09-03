class TpcCode < ActiveRecord::Base
  belongs_to :project, optional: true
  belongs_to :department, optional: true
  has_many :capex, foreign_key: 'tpc_code_id', dependent: :restrict_with_error
  has_many :opex, foreign_key: 'tpc_code_id', dependent: :restrict_with_error
  has_many :purchase_requests, foreign_key: 'tpc_code_id', dependent: :restrict_with_error
  
  validates :tpc_number, presence: true, length: { minimum: 3, maximum: 50 }
  validates :tpc_owner_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :tpc_name, length: { maximum: 150 }
  validates :tpc_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :description, length: { maximum: 1000 }
  validates :notes, length: { maximum: 2000 }
  
  # Ensure TPC number is unique within project scope (including global scope)
  validates :tpc_number, uniqueness: { scope: :project_id, case_sensitive: false }
  
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :global, -> { where('tpc_codes.project_id' => nil) }
  scope :for_project, ->(project) { where(project: project) }
  scope :search, ->(term) {
    pattern = "%#{term.to_s.downcase}%"
    left_joins(:department).where(
      "LOWER(tpc_codes.tpc_number) LIKE :q OR LOWER(tpc_codes.tpc_name) LIKE :q OR " \
      "LOWER(tpc_codes.tpc_owner_name) LIKE :q OR LOWER(departments.name) LIKE :q OR " \
      "LOWER(departments.code) LIKE :q OR LOWER(tpc_codes.tpc_email) LIKE :q OR " \
      "LOWER(tpc_codes.description) LIKE :q",
      q: pattern
    )
  }
  scope :ordered, -> { order(:tpc_number) }
  
  def self.available_for_project(project)
    # Return both global TPC codes and project-specific ones
    where('tpc_codes.project_id' => [nil, project&.id])
  end
  
  def global?
    project_id.nil?
  end
  
  def display_name
    # The name identifies the code; the owner stands in until names are
    # filled in, so an option never renders as a bare number.
    label = tpc_name.presence&.strip || tpc_owner_name.presence&.strip
    [tpc_number, label].compact.join(' - ')
  end

  def tpc_number_with_description
    parts = [tpc_number]
    parts << tpc_name if tpc_name.present?
    parts << department.name if department.present?
    if description.present?
      parts << description.truncate(50)
    else
      parts << tpc_owner_name
    end
    parts.join(' - ')
  end

  def scope_display
    global? ? 'Global' : project.name
  end
  
  def status_display
    is_active? ? 'Active' : 'Inactive'
  end
  
  def linked_capex_count
    capex.count
  end

  def linked_opex_count
    opex.count
  end

  def linked_purchase_requests_count
    purchase_requests.count
  end

  def total_linked_count
    linked_capex_count + linked_opex_count + linked_purchase_requests_count
  end
  
  def can_be_deleted?
    total_linked_count == 0
  end

  # Resolves an imported department by code first, then name, both matched
  # case-insensitively after stripping. Returns nil when nothing matches --
  # deliberately never creates, so a typo in a spreadsheet cannot quietly add
  # a department. Callers report the unmatched name instead.
  def self.resolve_department(name, code = nil)
    if code.to_s.strip.present?
      found = Department.where('LOWER(code) = ?', code.to_s.strip.downcase).first
      return found if found
    end
    return nil if name.to_s.strip.blank?

    Department.where('LOWER(name) = ?', name.to_s.strip.downcase).first
  end

  def as_json(options = {})
    super(options.merge(
      methods: [:display_name, :scope_display, :status_display, :linked_capex_count, :linked_opex_count, :total_linked_count]
    ))
  end
  
  # CSV export methods
  def self.to_csv(tpc_codes = all)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      csv << ['TPC Number', 'TPC Name', 'Owner Name', 'Department', 'Email', 'Description', 'Active', 'Project', 'Notes', 'Department Code']

      tpc_codes.includes(:project, :department).each do |tpc|
        csv << [
          tpc.tpc_number,
          tpc.tpc_name,
          tpc.tpc_owner_name,
          tpc.department&.name,
          tpc.tpc_email,
          tpc.description,
          tpc.is_active,
          tpc.project&.name,
          tpc.notes,
          tpc.department&.code
        ]
      end
    end
  end
  
  # JSON export methods
  def self.to_json_export(tpc_codes = all)
    tpc_codes.includes(:project, :department).map do |tpc|
      {
        tpc_number: tpc.tpc_number,
        tpc_name: tpc.tpc_name,
        tpc_owner_name: tpc.tpc_owner_name,
        department: tpc.department&.name,
        department_code: tpc.department&.code,
        tpc_email: tpc.tpc_email,
        description: tpc.description,
        is_active: tpc.is_active,
        project_name: tpc.project&.name,
        notes: tpc.notes
      }
    end.to_json
  end
  
  # Import methods
  def self.import_from_csv(file_path, project = nil)
    require 'csv'
    results = { created: 0, updated: 0, errors: [], unmatched_departments: [] }

    CSV.foreach(file_path, headers: true) do |row|
      begin
        tpc_data = {
          tpc_number: row['TPC Number']&.strip,
          tpc_name: row['TPC Name']&.strip,
          tpc_owner_name: row['Owner Name']&.strip,
          department: resolve_department(row['Department'], row['Department Code']),
          tpc_email: row['Email']&.strip,
          description: row['Description']&.strip,
          is_active: row['Active'].to_s.downcase.in?(['true', '1', 'yes', 'active']),
          notes: row['Notes']&.strip
        }

        if tpc_data[:department].nil? && row['Department'].to_s.strip.present?
          results[:unmatched_departments] << row['Department'].strip
        end

        # Handle project assignment
        if project
          tpc_data[:project_id] = project.id
        elsif row['Project'].present?
          found_project = Project.find_by(name: row['Project'].strip)
          tpc_data[:project_id] = found_project&.id
        end
        
        # Try to find existing TPC code
        existing_tpc = TpcCode.find_by(tpc_number: tpc_data[:tpc_number], project_id: tpc_data[:project_id])
        
        if existing_tpc
          existing_tpc.update!(tpc_data)
          results[:updated] += 1
        else
          TpcCode.create!(tpc_data)
          results[:created] += 1
        end
        
      rescue => e
        results[:errors] << "Row #{CSV.lineno}: #{e.message}"
      end
    end
    
    results
  end
  
  def self.import_from_json(file_path, project = nil)
    results = { created: 0, updated: 0, errors: [], unmatched_departments: [] }

    begin
      json_data = JSON.parse(File.read(file_path))

      json_data.each_with_index do |tpc_data, index|
        begin
          data = {
            tpc_number: tpc_data['tpc_number']&.strip,
            tpc_name: tpc_data['tpc_name']&.strip,
            tpc_owner_name: tpc_data['tpc_owner_name']&.strip,
            department: resolve_department(tpc_data['department'], tpc_data['department_code']),
            tpc_email: tpc_data['tpc_email']&.strip,
            description: tpc_data['description']&.strip,
            is_active: tpc_data['is_active'],
            notes: tpc_data['notes']&.strip
          }

          if data[:department].nil? && tpc_data['department'].to_s.strip.present?
            results[:unmatched_departments] << tpc_data['department'].strip
          end

          # Handle project assignment
          if project
            data[:project_id] = project.id
          elsif tpc_data['project_name'].present?
            found_project = Project.find_by(name: tpc_data['project_name'])
            data[:project_id] = found_project&.id
          end
          
          # Try to find existing TPC code
          existing_tpc = TpcCode.find_by(tpc_number: data[:tpc_number], project_id: data[:project_id])
          
          if existing_tpc
            existing_tpc.update!(data)
            results[:updated] += 1
          else
            TpcCode.create!(data)
            results[:created] += 1
          end
          
        rescue => e
          results[:errors] << "Record #{index + 1}: #{e.message}"
        end
      end
      
    rescue JSON::ParserError => e
      results[:errors] << "Invalid JSON format: #{e.message}"
    rescue => e
      results[:errors] << "Import error: #{e.message}"
    end
    
    results
  end
end
