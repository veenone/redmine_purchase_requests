class VendorsController < ApplicationController
  layout 'admin'
  
  before_action :require_admin, except: [:autocomplete]
  before_action :find_vendor, only: [:edit, :update, :destroy]
  
  def index
    @vendors = find_vendors
  end
  
  def new
    @vendor = Vendor.new
  end
  
  def create
    @vendor = Vendor.new(vendor_params)
    
    if @vendor.save
      flash[:notice] = l(:notice_vendor_created)
      redirect_to vendors_path
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @vendor.update(vendor_params)
      flash[:notice] = l(:notice_vendor_updated)
      redirect_to vendors_path
    else
      render :edit
    end
  end
  
  def destroy
    if @vendor.destroy
      flash[:notice] = l(:notice_vendor_deleted)
    else
      flash[:error] = l(:error_vendor_not_deleted)
    end
    redirect_to vendors_path
  end
  
  # Migrate vendors from settings to database
  def migrate_from_settings
    vendors = Setting.plugin_redmine_purchase_requests['vendors']
    if vendors.is_a?(Array) && vendors.any?
      count = 0
      
      vendors.each do |vendor_data|
        next if vendor_data['name'].blank?
        
        # Skip if vendor with same name already exists
        next if Vendor.exists?(name: vendor_data['name'])
        
        vendor = Vendor.new(
          name: vendor_data['name'],
          vendor_id: vendor_data['vendor_id'],
          address: vendor_data['address'],
          phone: vendor_data['phone'],
          contact_person: vendor_data['contact_person'],
          email: vendor_data['email']
        )
        
        count += 1 if vendor.save
      end
      
      if count > 0
        # Clear the vendors from settings to avoid duplicates
        settings = Setting.plugin_redmine_purchase_requests
        settings['vendors'] = []
        Setting.plugin_redmine_purchase_requests = settings
        
        flash[:notice] = l(:notice_vendors_migrated, count: count)
      else
        flash[:warning] = l(:warning_no_vendors_migrated)
      end
    else
      flash[:error] = l(:error_no_vendors_to_migrate)
    end
    
    redirect_to vendors_path
  end
  
  # API for autocomplete
  def autocomplete
    respond_to do |format|
      format.json do
        if params[:id].present?
          # Request for specific vendor details
          vendor = Vendor.find_by(id: params[:id])
          if vendor
            render json: vendor.attributes
          else
            render json: {}
          end
        elsif params[:term].present?
          # Search for vendors matching term
          vendors = Vendor.search(params[:term]).limit(10)
          render json: vendors.map { |v| { 
            id: v.id, 
            label: v.display_name, 
            value: v.name,
            vendor_id: v.vendor_id,
            address: v.address,
            phone: v.phone,
            contact_person: v.contact_person,
            email: v.email
          }}
        else
          render json: []
        end
      end
    end
  end
  
  def export
    @vendors = find_vendors
    
    respond_to do |format|
      format.html { redirect_to import_export_vendors_path }
      format.csv do
        send_data generate_csv(@vendors), 
                  filename: "vendors_export_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv'
      end
      format.json do
        send_data @vendors.to_json(except: [:created_at, :updated_at]),
                  filename: "vendors_export_#{Date.current.strftime('%Y%m%d')}.json",
                  type: 'application/json'
      end
    end
  end
  
  def import
    unless params[:file]
      flash[:error] = l(:error_no_file_selected)
      redirect_to vendors_path
      return
    end
    
    file = params[:file]
    
    begin
      case file.content_type
      when 'text/csv', 'application/vnd.ms-excel'
        import_from_csv(file)
      when 'application/json'
        import_from_json(file)
      else
        flash[:error] = l(:error_unsupported_file_format)
        redirect_to vendors_path
        return
      end
      
      flash[:notice] = l(:notice_vendors_imported_successfully)
    rescue => e
      flash[:error] = l(:error_vendor_import_failed, error: e.message)
    end
    
    redirect_to vendors_path
  end
  
  def import_template
    respond_to do |format|
      format.csv do
        csv_data = generate_template_csv
        send_data csv_data,
                  filename: "vendor_import_template.csv",
                  type: 'text/csv'
      end
    end
  end
  
  def import_export
    # Display the import/export page
  end
  
  private
  
  def find_vendor
    @vendor = Vendor.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_vendors
    Vendor.sorted
  end
  
  def vendor_params
    params.require(:vendor).permit(:name, :email, :phone, :website, :address, :contact_person, :notes, :is_active)
  end
  
  def generate_csv(vendors)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << [
        l(:field_name),
        l(:field_email), 
        l(:field_phone),
        l(:field_website),
        l(:field_address),
        l(:field_contact_person),
        l(:field_notes),
        l(:field_is_active)
      ]
      
      vendors.each do |vendor|
        csv << [
          vendor.name,
          vendor.email,
          vendor.phone,
          vendor.website,
          vendor.address,
          vendor.contact_person,
          vendor.notes,
          vendor.is_active? ? 'Yes' : 'No'
        ]
      end
    end
  end
  
  def generate_template_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << [
        l(:field_name),
        l(:field_email), 
        l(:field_phone),
        l(:field_website),
        l(:field_address),
        l(:field_contact_person),
        l(:field_notes),
        l(:field_is_active)
      ]
      
      # Add sample row
      csv << [
        'Sample Vendor Inc.',
        'contact@samplevendor.com',
        '+1-555-0123',
        'https://www.samplevendor.com',
        '123 Business St, City, State 12345',
        'John Smith',
        'Reliable supplier for office equipment',
        'Yes'
      ]
    end
  end
  
  def import_from_csv(file)
    require 'csv'
    
    imported_count = 0
    updated_count = 0
    errors = []
    
    CSV.foreach(file.path, headers: true, encoding: 'utf-8') do |row|
      next if row[l(:field_name)].blank?
      
      vendor_data = {
        name: row[l(:field_name)],
        email: row[l(:field_email)],
        phone: row[l(:field_phone)],
        website: row[l(:field_website)],
        address: row[l(:field_address)],
        contact_person: row[l(:field_contact_person)],
        notes: row[l(:field_notes)],
        is_active: row[l(:field_is_active)].to_s.downcase.in?(['yes', 'true', '1'])
      }
      
      existing_vendor = Vendor.find_by(name: vendor_data[:name])
      
      if existing_vendor
        if existing_vendor.update(vendor_data)
          updated_count += 1
        else
          errors << "Row #{row.line_number}: #{existing_vendor.errors.full_messages.join(', ')}"
        end
      else
        vendor = Vendor.new(vendor_data)
        if vendor.save
          imported_count += 1
        else
          errors << "Row #{row.line_number}: #{vendor.errors.full_messages.join(', ')}"
        end
      end
    end
    
    if errors.any?
      raise "Import completed with errors: #{errors.join('; ')}. Imported: #{imported_count}, Updated: #{updated_count}"
    end
    
    flash[:notice] = l(:notice_vendors_imported, count: imported_count, updated: updated_count)
  end
  
  def import_from_json(file)
    data = JSON.parse(file.read)
    imported_count = 0
    updated_count = 0
    
    data.each do |vendor_data|
      next if vendor_data['name'].blank?
      
      existing_vendor = Vendor.find_by(name: vendor_data['name'])
      
      if existing_vendor
        existing_vendor.update!(vendor_data.except('id', 'created_at', 'updated_at'))
        updated_count += 1
      else
        Vendor.create!(vendor_data.except('id', 'created_at', 'updated_at'))
        imported_count += 1
      end
    end
    
    flash[:notice] = l(:notice_vendors_imported, count: imported_count, updated: updated_count)
  end
end
