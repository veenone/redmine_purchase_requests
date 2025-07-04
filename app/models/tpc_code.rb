class TpcCode < ActiveRecord::Base
  belongs_to :project, optional: true
  has_many :capex, foreign_key: 'tpc_code_id', dependent: :restrict_with_error
  has_many :opex, foreign_key: 'tpc_code_id', dependent: :restrict_with_error
  
  validates :tpc_number, presence: true, length: { minimum: 3, maximum: 50 }
  validates :tpc_owner_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :tpc_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :description, length: { maximum: 1000 }
  validates :notes, length: { maximum: 2000 }
  
  # Ensure TPC number is unique within project scope (including global scope)
  validates :tpc_number, uniqueness: { scope: :project_id, case_sensitive: false }
  
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :global, -> { where(project_id: nil) }
  scope :for_project, ->(project) { where(project: project) }
  scope :search, ->(term) { 
    where("LOWER(tpc_number) LIKE ? OR LOWER(tpc_owner_name) LIKE ? OR LOWER(tpc_email) LIKE ? OR LOWER(description) LIKE ?", 
          "%#{term.to_s.downcase}%", "%#{term.to_s.downcase}%", "%#{term.to_s.downcase}%", "%#{term.to_s.downcase}%") 
  }
  scope :ordered, -> { order(:tpc_number) }
  
  def self.available_for_project(project)
    # Return both global TPC codes and project-specific ones
    where(project_id: [nil, project&.id])
  end
  
  def global?
    project_id.nil?
  end
  
  def display_name
    "#{tpc_number} - #{tpc_owner_name}"
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
  
  def total_linked_count
    linked_capex_count + linked_opex_count
  end
  
  def can_be_deleted?
    total_linked_count == 0
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
      csv << ['TPC Number', 'Owner Name', 'Email', 'Description', 'Active', 'Project', 'Notes']
      
      tpc_codes.includes(:project).each do |tpc|
        csv << [
          tpc.tpc_number,
          tpc.tpc_owner_name,
          tpc.tpc_email,
          tpc.description,
          tpc.is_active,
          tpc.project&.name,
          tpc.notes
        ]
      end
    end
  end
  
  # JSON export methods
  def self.to_json_export(tpc_codes = all)
    tpc_codes.includes(:project).map do |tpc|
      {
        tpc_number: tpc.tpc_number,
        tpc_owner_name: tpc.tpc_owner_name,
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
    results = { created: 0, updated: 0, errors: [] }
    
    CSV.foreach(file_path, headers: true) do |row|
      begin
        tpc_data = {
          tpc_number: row['TPC Number']&.strip,
          tpc_owner_name: row['Owner Name']&.strip,
          tpc_email: row['Email']&.strip,
          description: row['Description']&.strip,
          is_active: row['Active'].to_s.downcase.in?(['true', '1', 'yes', 'active']),
          notes: row['Notes']&.strip
        }
        
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
    results = { created: 0, updated: 0, errors: [] }
    
    begin
      json_data = JSON.parse(File.read(file_path))
      
      json_data.each_with_index do |tpc_data, index|
        begin
          data = {
            tpc_number: tpc_data['tpc_number']&.strip,
            tpc_owner_name: tpc_data['tpc_owner_name']&.strip,
            tpc_email: tpc_data['tpc_email']&.strip,
            description: tpc_data['description']&.strip,
            is_active: tpc_data['is_active'],
            notes: tpc_data['notes']&.strip
          }
          
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
