Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  
  resources :playlists, only: [:index, :show, :new, :create, :destroy] do
    member do
      patch :rename
    end
  end

  # resources :songmarks, only: [:destroy] do
  resources :playlist_items, only: [:destroy] do
    collection do
      post :like_all_songs
      post :dislike_all_songs
    end
    member do
      post :like
      post :dislike
    end
  end

end
