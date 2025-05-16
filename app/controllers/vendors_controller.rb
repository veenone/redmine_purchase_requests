class VendorsController < ApplicationController
  layout 'admin'
  
  before_action :require_admin, except: [:autocomplete]
  before_action :find_vendor, only: [:edit, :update, :destroy]
  
  def index
    @vendors = Vendor.sorted
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
          vendors = Vendor.where("LOWER(name) LIKE ?", "%#{params[:term].downcase}%").limit(10)
          render json: vendors.map { |v| { 
            id: v.id, 
            label: v.name, 
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
  
  private
  
  def find_vendor
    @vendor = Vendor.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def vendor_params
    params.require(:vendor).permit(:name, :vendor_id, :address, :phone, :contact_person, :email)
  end
end
