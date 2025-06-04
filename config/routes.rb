Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

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
end
