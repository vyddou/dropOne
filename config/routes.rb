# config/routes.rb
Rails.application.routes.draw do
  # Supprimez "get 'users/show'" si vous avez "resources :users, only: [:show]" ci-dessous
  # get 'users/show'

  devise_for :users
  root to: "pages#home"

  resources :users, only: [:show] do # Pour user_path(user)
      member do
      post :follow
      delete :unfollow
      patch :update_description
    end
  end

  resources :playlists, only: [:index, :show, :new, :create, :destroy] do
    member do
      patch :rename
    end
  end
  # La deuxième définition de "resources :playlists" a été supprimée.

  resources :playlist_items, only: [:destroy] do
    collection do
      post :like_all_songs
      post :dislike_all_songs
    end
    member do
      post :like
      post :dislike
      delete :remove_from_likes  # Nouvelle route spécifique
    end
  end

  # Route spécifique pour la recherche Deezer avant la ressource posts générale
  get 'posts/deezer_search', to: 'posts#deezer_search'

  # Ressources pour les posts, incluant :show pour post_path et la route de vote
  resources :posts, only: [:new, :create, :edit, :update, :show, :destroy] do
    member do
      post 'vote' # Crée vote_post_path(post) pour POST /posts/:id/vote
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

end
