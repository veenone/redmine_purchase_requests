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
end