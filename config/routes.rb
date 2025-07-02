# Routes for purchase requests plugin

Rails.application.routes.draw do
  resources :projects do
    resources :purchase_requests do
      collection do
        get 'dashboard'
      end
    end
    
    # Add project-scoped vendor management
    resources :vendors, only: [:index], controller: 'project_vendors' do
      collection do
        get 'manage'
      end
    end
    
    # Add CAPEX management routes  
    resources :capex, path: 'capex', as: 'capex' do
      collection do
        get 'dashboard'
      end
    end
    
    # Add OPEX management routes  
    resources :opex, path: 'opex', as: 'opex' do
      collection do
        get 'dashboard'
      end
    end
    
    # Add OPEX categories management routes
    resources :opex_categories, only: [:create, :edit, :update, :destroy]
  end

  resources :purchase_request_statuses, only: [:index, :new, :create, :edit, :update, :destroy]
  
  # Keep global vendors for data storage
  resources :vendors, except: [:show] do
    collection do
      get 'autocomplete'
      post 'migrate_from_settings'
      get 'export'
      post 'import'
      get 'import_template'
      get 'import_export'
    end
  end
end