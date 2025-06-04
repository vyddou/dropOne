# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  CarouselItem = Struct.new(
    :id_for_links,
    :origin,
    :title,
    :artist,
    :cover_url,
    :genre,
    :description,
    :user,
    :net_votes,
    :created_at_for_sort,
    :deezer_link,
    :preview_url,
    :db_post_object
  )

  def home
    Rails.logger.debug "--- DEBUT PagesController#home ---"

    # 1. Récupérer les posts de l'application créés aujourd'hui
    todays_app_posts = Post
      .left_joins(:votes) # MODIFICATION ICI: Utilise left_joins pour la table votes
      .includes(:track, :user, track: :genres) # Garde les includes pour les autres associations
      .where("posts.created_at >= ?", Time.zone.now.beginning_of_day)
      .select(
        "posts.*", # Important de sélectionner toutes les colonnes de posts pour que l'objet Post soit correctement initialisé
        "COALESCE(SUM(CASE WHEN votes.vote_type = TRUE THEN 1 ELSE 0 END), 0) AS hot_votes_count",
        "COALESCE(SUM(CASE WHEN votes.vote_type = FALSE THEN 1 ELSE 0 END), 0) AS cold_votes_count",
        "(COALESCE(SUM(CASE WHEN votes.vote_type = TRUE THEN 1 ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN votes.vote_type = FALSE THEN 1 ELSE 0 END), 0)) AS calculated_net_votes"
      )
      .group("posts.id") # Grouper par posts.id est suffisant si c'est la PK (PostgreSQL)
                         # Pour d'autres DB, il faudrait lister toutes les colonnes de posts non agrégées.

    Rails.logger.debug "Nombre de 'Todays App Posts' récupérés de la DB: #{todays_app_posts.try(:length) || 0}"
    # Affiche la requête SQL générée pour le débogage
    Rails.logger.debug "SQL pour todays_app_posts: #{todays_app_posts.to_sql}"


    app_carousel_items = todays_app_posts.map do |post|
      CarouselItem.new(
        post.id,
        :app,
        post.track&.title,
        post.track&.artist_name,
        post.track&.cover_url,
        post.track&.genres&.first&.name&.capitalize,
        post.description,
        post.user,
        post.attributes['calculated_net_votes'] || 0, # Accède à l'attribut calculé
        post.created_at,
        post.track&.link_deezer,
        post.track&.preview_url,
        post
      )
    end
    Rails.logger.debug "Nombre de 'App Carousel Items' après transformation: #{app_carousel_items.length}"

    # 2. Récupérer les suggestions de Deezer
    playlist_id_top_france = 1313621735 # Top France
    new_cache_key = "hourly_deezer_top_france_30_tracks_v4"

    deezer_raw_suggestions = Rails.cache.fetch(new_cache_key, expires_in: 1.hour) do
      Rails.logger.info "CACHE MISS pour la clé '#{new_cache_key}'. Appel à DeezerService..."
      DeezerService.fetch_playlist_tracks(playlist_id: playlist_id_top_france, limit: 30)
    end

    if deezer_raw_suggestions.nil?
      Rails.logger.warn "Le cache a retourné NIL pour '#{new_cache_key}'. Tentative de fetch direct."
      deezer_raw_suggestions = DeezerService.fetch_playlist_tracks(playlist_id: playlist_id_top_france, limit: 30)
    end
    deezer_raw_suggestions ||= []

    Rails.logger.debug "Nombre de 'Deezer Raw Suggestions' (depuis cache ou service): #{deezer_raw_suggestions.try(:count) || 0}"

    deezer_carousel_items = deezer_raw_suggestions.map do |deezer_track|
      CarouselItem.new(
        deezer_track.id,
        :deezer,
        deezer_track.title,
        deezer_track.artist,
        deezer_track.cover_url,
        "Hits",
        nil,
        nil,
        0,
        Time.now,
        deezer_track.link_deezer,
        deezer_track.preview_url,
        nil
      )
    end
    Rails.logger.debug "Nombre de 'Deezer Carousel Items' après transformation: #{deezer_carousel_items.length}"

    # 3. Combiner et trier
    all_items = app_carousel_items + deezer_carousel_items
    Rails.logger.debug "Nombre total d'items avant tri: #{all_items.try(:count) || 0}"

    @carousel_items = all_items.sort_by { |item| [-item.net_votes, -item.created_at_for_sort.to_i] }
    Rails.logger.debug "Nombre de '@carousel_items' après tri (passés à la vue): #{@carousel_items.try(:count) || 0}"
    Rails.logger.debug "--- FIN PagesController#home ---"

  rescue StandardError => e
    Rails.logger.error "ERREUR dans PagesController#home: #{e.message}"
    e.backtrace.first(10).each { |line| Rails.logger.error line }
    @carousel_items = []
  end
end
