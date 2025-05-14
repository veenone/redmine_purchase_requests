# Routes for purchase requests plugin

Rails.application.routes.draw do
  resources :projects do
    resources :purchase_requests do
      collection do
        get 'dashboard'
      end
    end
  end

  resources :purchase_request_statuses, only: [:index, :new, :create, :edit, :update, :destroy]
  
  resources :vendors, except: [:show] do
    collection do
      get 'autocomplete'
      post 'migrate_from_settings'
    end
  end
end