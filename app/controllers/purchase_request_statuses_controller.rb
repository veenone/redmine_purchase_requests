class PurchaseRequestStatusesController < ApplicationController
  layout 'admin'
  before_action :require_admin
  
  def index
    @statuses = PurchaseRequestStatus.sorted
  end
  
  def new
    @status = PurchaseRequestStatus.new
  end
  
  def create
    @status = PurchaseRequestStatus.new(purchase_request_status_params)
    if @status.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to purchase_request_statuses_path
    else
      render :new
    end
  end
  
  def edit
    @status = PurchaseRequestStatus.find(params[:id])
  end
  
  def update
    @status = PurchaseRequestStatus.find(params[:id])
    if @status.update(purchase_request_status_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to purchase_request_statuses_path
    else
      render :edit
    end
  end
  
  def destroy
    status = PurchaseRequestStatus.find(params[:id])
    if status.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:error_unable_delete_status)
    end
    redirect_to purchase_request_statuses_path
  end
  
  private
  
  def purchase_request_status_params
    params.require(:purchase_request_status).permit(:name, :position, :is_closed)
  end
end