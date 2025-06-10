# config/routes.rb

Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  get 'posts/deezer_search', to: 'posts#deezer_search'

  resources :users, only: [:show] do
    member do
      post :follow
      delete :unfollow
      patch :update_description
      get :activity
    end
  end

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
      delete :remove_from_likes
    end
  end

  # --- MODIFICATION ICI ---
  # On supprime le bloc de vote de 'posts' car il sera géré par la nouvelle route
  resources :posts, only: [:new, :create, :edit, :update, :show, :destroy]
  # La ligne "member do post 'vote' end" a été supprimée.

  # L'ancienne route pour voter sur les suggestions est aussi supprimée.
  # post 'tracks/:id/create_post_and_vote', ...

  # On la remplace par une route unique et plus propre pour tous les votes :
  post 'tracks/:track_id/vote', to: 'votes#create', as: 'vote_on_track'
  # --- FIN DE LA MODIFICATION ---

  resources :tracks, only: [] do
    get :preview, on: :member
  end

  resources :conversations, only: [:index, :show, :create, :destroy] do
    resources :messages, only: [:create]
  end

  get 'search', to: 'search#index', as: 'search'
  get 'search_suggestions', to: 'search#suggestions'

  get "up" => "rails/health#show", as: :rails_health_check
end
