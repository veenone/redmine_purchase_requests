class DepartmentsController < ApplicationController
  before_action :authorize_departments
  before_action :find_department, only: [:edit, :update, :destroy]

  def index
    @departments = Department.ordered
    # One grouped count instead of a COUNT per row in the view.
    @tpc_counts = TpcCode.where.not(department_id: nil).group(:department_id).count
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

  # Departments are global data, so the permissions are declared global in
  # init.rb and checked without a project. Viewing is separated from
  # managing so a role can be granted the list without the ability to edit
  # it. Admins keep access regardless, as elsewhere in this plugin.
  def authorize_departments
    return true if User.current.admin?

    required = action_name == 'index' ? :view_departments : :manage_departments
    return true if User.current.allowed_to?(required, nil, global: true)

    deny_access
  end

  def find_department
    @department = Department.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def department_params
    params.require(:department).permit(:code, :name)
  end
end
