class DepartmentsController < ApplicationController
  # Departments are global data — one list, shared by every project — but the
  # page is reachable from two places, and it should stay where the user was.
  #
  # Reached from a project's Budget Management menu, params[:project_id] is
  # set: @project is assigned, Redmine renders the project layout, the project
  # menu stays visible and highlighted, and every link this page emits keeps
  # the project in the URL. Reached globally (plugin settings, a direct URL),
  # there is no project and it renders standalone.
  #
  # The rows are identical either way. Only the surroundings differ.
  before_action :find_optional_project
  before_action :authorize_departments
  before_action :find_department, only: [:edit, :update, :destroy]

  helper_method :departments_index_path_for, :new_department_path_for,
                :edit_department_path_for, :department_path_for

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
      redirect_to departments_index_path_for
    else
      render :new
    end
  end

  def edit; end

  def update
    if @department.update(department_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to departments_index_path_for
    else
      render :edit
    end
  end

  def destroy
    # dependent: :nullify, so TPC codes survive and simply lose the link.
    @department.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to departments_index_path_for
  end

  private

  # Present only on the project-scoped route. A project whose purchase_requests
  # module is off has no business rendering this inside its layout, so that is
  # a 404 rather than a silent fall back to the global page — the URL asked for
  # something specific.
  def find_optional_project
    return true if params[:project_id].blank?

    @project = Project.find(params[:project_id])
    render_404 unless @project.module_enabled?(:purchase_requests)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Viewing is separated from managing so a role can be granted the list
  # without the ability to edit it. Admins keep access regardless, as
  # elsewhere in this plugin.
  #
  # Inside a project the check is made against that project, so a user's role
  # there governs; globally it falls back to the global check. The permissions
  # are declared global: true in init.rb, which allows both.
  def authorize_departments
    return true if User.current.admin?

    required = action_name == 'index' ? :view_departments : :manage_departments
    permitted = if @project
                  User.current.allowed_to?(required, @project)
                else
                  User.current.allowed_to?(required, nil, global: true)
                end
    return true if permitted

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

  # Path helpers that keep whichever context the request arrived in. Views call
  # these rather than the bare route helpers, so a page opened inside a project
  # never emits a link that drops the user out of it.
  def departments_index_path_for
    @project ? project_departments_path(@project) : departments_path
  end

  def new_department_path_for
    @project ? new_project_department_path(@project) : new_department_path
  end

  def edit_department_path_for(department)
    @project ? edit_project_department_path(@project, department) : edit_department_path(department)
  end

  def department_path_for(department)
    @project ? project_department_path(@project, department) : department_path(department)
  end
end
