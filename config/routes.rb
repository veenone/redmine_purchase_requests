# Add routes for purchase request statuses

Rails.application.routes.draw do
  resources :purchase_request_statuses, only: [:index, :new, :create, :edit, :update, :destroy]
  
  resources :purchase_requests do
    collection do
      get 'dashboard'
    end
  end
  
  # Include any other routes your plugin needs
end