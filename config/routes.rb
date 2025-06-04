# config/routes.rb
Rails.application.routes.draw do


  devise_for :users
  root to: "pages#home"

  resources :users, only: [:show] # user path

  # Définition unique pour les playlists
  resources :playlists, only: [:index, :show, :new, :create, :destroy] do
    member do
      patch :rename
    end
  end


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


  resources :posts, only: [:new, :create, :edit, :update]
  get 'posts/deezer_search', to: 'posts#deezer_search'


 

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index" # Commenté car votre root est déjà défini
end
