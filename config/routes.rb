# Routes for purchase requests plugin

RedmineApp::Application.routes.draw do
  resources :projects do
    resources :purchase_requests do
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
        get 'dashboard_data'
      end
      member do
        get 'quarterly_data'
      end
    end
    
    # Add OPEX management routes  
    resources :opex, path: 'opex', as: 'opex' do
      collection do
        get 'dashboard'
        get 'dashboard_data'
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
        get 'import_export'
        post 'import'
        get 'export'
      end
    end
  end

  resources :purchase_request_statuses, only: [:index, :new, :create, :edit, :update, :destroy]
  
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
  get 'tpc_codes/import_export', to: 'tpc_codes#global_import_export', as: 'import_export_global_tpc_codes'
  post 'tpc_codes/import', to: 'tpc_codes#global_import', as: 'import_global_tpc_codes'
  get 'tpc_codes/export', to: 'tpc_codes#global_export', as: 'export_global_tpc_codes'
  get 'tpc_codes/:id', to: 'tpc_codes#global_show', as: 'global_tpc_code'
  get 'tpc_codes/:id/edit', to: 'tpc_codes#global_edit', as: 'edit_global_tpc_code'
  patch 'tpc_codes/:id', to: 'tpc_codes#global_update'
  put 'tpc_codes/:id', to: 'tpc_codes#global_update'
  delete 'tpc_codes/:id', to: 'tpc_codes#global_destroy'
  
  # Handle favicon.ico requests to prevent 404 errors in logs
  get '/favicon.ico', to: proc { [204, {}, []] }
end