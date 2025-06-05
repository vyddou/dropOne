Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"


    get 'posts/deezer_search', to: 'posts#deezer_search'


  resources :users, only: [:show] do # Pour user_path(user)
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
      delete :remove_from_likes  # Nouvelle route spécifique
    end
  end

  resources :posts, only: [:new, :create, :edit, :update, :show, :destroy] do
    member do
      post 'vote' # Pour voter sur un post existant
    end
  end

  # Route pour créer un post à partir d'un track Deezer et voter
  # :id ici sera le deezer_track_id
  post 'tracks/:id/create_post_and_vote', to: 'posts#create_post_from_deezer_and_vote', as: 'create_post_and_vote_on_track'

  resources :conversations, only: [:index, :show, :create, :destroy] do
    resources :messages, only: [:create]
  end

  # Routes pour la recherche
  get 'search', to: 'search#index', as: 'search'
  get 'search_suggestions', to: 'search#suggestions'

  get "up" => "rails/health#show", as: :rails_health_check
end
