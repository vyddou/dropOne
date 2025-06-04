# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  resources :users, only: [:show] # Pour user_path(user)

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

  # Route spécifique pour la recherche Deezer avant les posts
  get 'posts/deezer_search', to: 'posts#deezer_search'

  resources :posts, only: [:new, :create, :edit, :update, :show, :destroy] do
    member do
      post :vote # Crée vote_post_path(post) pour POST /posts/:id/vote
    end
  end

  resources :conversations, only: [:index, :show, :create,:destroy] do
    resources :messages, only: [:create]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
