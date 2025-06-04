# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home] # Permet l'accès public à la page d'accueil

  def home
    # Récupère les posts de l'application créés aujourd'hui et les trie par score net de votes
    # (en supposant vote_type: true pour 'hot', false pour 'cold')
    @todays_app_posts_sorted = Post.includes(:track)
      .left_joins(:votes) # Utilise left_joins pour inclure les posts même sans votes
      .where("posts.created_at >= ?", Time.zone.now.beginning_of_day)
      .select(
        "posts.*",
        "COALESCE(SUM(CASE WHEN votes.vote_type = TRUE THEN 1 ELSE 0 END), 0) AS hot_votes",
        "COALESCE(SUM(CASE WHEN votes.vote_type = FALSE THEN 1 ELSE 0 END), 0) AS cold_votes",
        "(COALESCE(SUM(CASE WHEN votes.vote_type = TRUE THEN 1 ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN votes.vote_type = FALSE THEN 1 ELSE 0 END), 0)) AS net_votes"
      )
      .group("posts.id") # Doit grouper par toutes les colonnes de posts si elles ne sont pas dans une fonction d'agrégation,
                         # ou au moins par posts.id si c'est la clé primaire (PostgreSQL le gère bien).
      .order("net_votes DESC, posts.created_at DESC") # Trie par score net, puis par date de création

    # Récupère les suggestions de Deezer (Goa/Mental), mises en cache pour 1 heure
    #  utilisées pour le carrousel @todays_tracks
    # ID de playlist exemple pour "Goa Trance & Psychedelic": 7017501704
    # Vous pouvez chercher d'autres IDs sur Deezer.
    playlist_id_goa = 7017501704
    @todays_tracks = Rails.cache.fetch("hourly_deezer_goa_suggestions_10", expires_in: 1.hour) do
      Rails.logger.info "Fetching new Deezer Goa suggestions (10 tracks) for cache..."
      DeezerService.fetch_playlist_tracks(playlist_id: playlist_id_goa, limit: 10)
    end

    # S'assure que @todays_tracks est un tableau même en cas d'erreur du service ou du cache
    @todays_tracks ||= []

  rescue StandardError => e
    # En cas d'erreur lors de la récupération des données,
    Rails.logger.error "Error in PagesController#home: #{e.message}\n#{e.backtrace.join("\n")}"
    @todays_app_posts_sorted = [] # Fournit un tableau vide pour éviter les erreurs dans la vue
    @todays_tracks = []           # Fournit un tableau vide pour éviter les erreurs dans la vue
  end
end
