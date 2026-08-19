class DepartmentsController < ApplicationController
  before_action :require_admin
  before_action :find_department, only: [:edit, :update, :destroy]

  def index
    @departments = Department.ordered
  end

  def new
    @department = Department.new
  end

  def create
    @department = Department.new(department_params)
    if @department.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to departments_path
    else
      render :new
    end
  end

  def edit; end

  def update
    if @department.update(department_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to departments_path
    else
      render :edit
    end
  end

  def destroy
    # dependent: :nullify, so TPC codes survive and simply lose the link.
    @department.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to departments_path
  end

  private

  def find_department
    @department = Department.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def department_params
    params.require(:department).permit(:code, :name)
  end
end
