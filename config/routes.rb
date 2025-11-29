Rails.application.routes.draw do
  devise_for :users, only: [:sessions]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Sidekiq Web UI - protected with authentication
  require "sidekiq/web"
  authenticate :user do
    mount Sidekiq::Web => "/sidekiq"
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"

  resources :activities, only: [:index, :show, :new, :create]
  
  get "maps", to: "maps#index"
  get "maps/trackpoints", to: "maps#trackpoints"
  
  get "settings", to: "settings#show"
  patch "settings", to: "settings#update"
  
  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication routes
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"
      post "auth/logout", to: "auth#logout"
      get "auth/me", to: "auth#me"
      
      # Resource routes
      resources :activities, only: [:index, :show, :create, :update]
    end
  end
end
