GojiServer::Application.routes.draw do

  if GojiServer::Application.config.admin == "rails"
    mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  else
    devise_for :admin_users, ActiveAdmin::Devise.config
    ActiveAdmin.routes(self)
  end

  # End user facing pages
  get '/store/go', to: 'store#go'
  get '/store/device_confirmation/:id', to: 'store#device_confirmation', as: "store_device_confirmation"

  devise_for :accounts, :only => [:sessions]

  resources :pictures
  resources :user_devices
  resources :devices
  resources :locks
  #resources :locks_users
  resources :users, :constraints => {:id => /[^\/]+?/, :format => /json/} # Allow period in :id (.com, etc)
  resources :events
  resources :keys
  resources :firmwares
  resources :store
  resources :logs

  # singleton routing
  resource  :authtoken, :controller => "authtoken"
  resource  :utility,   :controller => "utility"
  get '/utility/error', to: "utility#error"
  get '/utility/soft_error', to: "utility#soft_error"
  post '/utility/download_log_file', to: "utility#download_log_file"

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "home#index"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
  #
  match '/locks/serial/:lock_serial', :to => 'locks#sync', :via => :put
  match '/locks/credentials/serial/:lock_serial', :to => 'locks#get_credentials', :via => :get
  match '/locks/credentials/:id', :to => 'locks#get_credentials', :via => :get
  #match '/locks_users/:lock_id', :to => 'locks_users#update', :via => :put
  match '/logs/serial/:lock_serial', :to => 'logs#show', :via => :get
  match '/logs/device/:device_id', :to => 'logs#show', :via => :get
  match '/logs/ua_token/:ua_token', :to => 'logs#show', :via => :get
end
