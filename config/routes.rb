# Routes for purchase requests plugin

RedmineApp::Application.routes.draw do
  resources :projects do
    resources :purchase_requests do
      member do
        post 'create_workflow_issue'
      end
      collection do
        get 'dashboard'
      end
    end
    
    # Add project-scoped vendor management
    resources :vendors, only: [:index, :new, :create], controller: 'project_vendors' do
      collection do
        get 'manage'
      end
    end
    
    # Add CAPEX management routes  
    resources :capex, path: 'capex', as: 'capex' do
      collection do
        get 'dashboard'
        get 'export_csv'
        get 'export_xlsx'
        get 'export_pdf'
      end
      member do
        get 'quarterly_data'
      end
    end
    
    # Add OPEX management routes  
    resources :opex, path: 'opex', as: 'opex' do
      collection do
        get 'dashboard'
        get 'export_csv'
        get 'export_xlsx'
        get 'export_pdf'
      end
      member do
        get 'quarterly_data'
      end
    end
    
    # Add OPEX categories management routes
    resources :opex_categories, only: [:create, :edit, :update, :destroy]
    
    # Add TPC codes management routes (project-scoped)
    resources :tpc_codes, path: 'tpc_codes' do
      collection do
        get 'dashboard'
        get 'import_export'
        post 'import'
        get 'export'
      end
    end
    
    # Departments are global data, but reachable from inside a project so
    # the Budget Management menu can link to them without dropping the user
    # out of the project. Same controller and same rows either way — the
    # controller notices params[:project_id] and keeps the context.
    resources :departments, except: [:show]

    # Add project-scoped reports
    resources :reports, only: [:index] do
      collection do
        get 'purchase_requests'
        get 'vendors'
        get 'tpc_codes'
        get 'capex'
        get 'opex'
        get 'overview'
      end
    end
  end

  resources :purchase_request_statuses, only: [:index, :new, :create, :edit, :update, :destroy]

  # Workflow templates management
  resources :purchase_request_workflow_templates do
    collection do
      post 'create_defaults'
      post 'update_positions'
    end
  end
  
  # Keep global vendors for data storage
  resources :vendors do
    collection do
      get 'autocomplete'
      post 'migrate_from_settings'
      get 'export'
      post 'import'
      get 'import_template'
      get 'import_export'
    end
  end
  
  # Global TPC codes management
  get 'tpc_codes', to: 'tpc_codes#global_index', as: 'global_tpc_codes'
  get 'tpc_codes/new', to: 'tpc_codes#global_new', as: 'new_global_tpc_codes'
  post 'tpc_codes', to: 'tpc_codes#global_create'
  get 'tpc_codes/dashboard', to: 'tpc_codes#dashboard', as: 'tpc_codes_dashboard'
  get 'tpc_codes/import_export', to: 'tpc_codes#global_import_export', as: 'import_export_global_tpc_codes'
  post 'tpc_codes/import', to: 'tpc_codes#global_import', as: 'import_global_tpc_codes'
  get 'tpc_codes/export', to: 'tpc_codes#global_export', as: 'export_global_tpc_codes'
  get 'tpc_codes/:id', to: 'tpc_codes#global_show', as: 'global_tpc_code'
  get 'tpc_codes/:id/edit', to: 'tpc_codes#global_edit', as: 'edit_global_tpc_code'
  patch 'tpc_codes/:id', to: 'tpc_codes#global_update'
  put 'tpc_codes/:id', to: 'tpc_codes#global_update'
  delete 'tpc_codes/:id', to: 'tpc_codes#global_destroy'
  resources :departments, except: [:show]
  
  # Global reports
  resources :reports, only: [:index] do
    collection do
      get 'purchase_requests'
      get 'vendors'
      get 'tpc_codes'
      get 'capex'
      get 'opex'
      get 'overview'
    end
  end
  
  # Handle favicon.ico requests to prevent 404 errors in logs
  get '/favicon.ico', to: proc { [204, {}, []] }
  
  # Handle Chrome DevTools requests to prevent 404 errors in logs
  get '/.well-known/appspecific/com.chrome.devtools.json', to: proc { [204, {}, []] }
end