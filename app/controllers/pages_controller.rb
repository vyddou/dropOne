# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  # Crée un objet simple pour simuler l'affichage de "Suggéré par Deezer"

  CarouselItem = Struct.new(
    :id_for_links, :origin, :title, :artist, :cover_url, :genre, :description,
    :user, :net_votes, :created_at_for_sort, :deezer_link, :preview_url, :db_post_object
  )

  def home
    # 1. Récupérer TOUS les posts du jour (utilisateurs réels ET système Deezer)
    todays_posts = Post
      .left_joins(:votes)
      .includes(:track, :user) # Eager loading
      .where("posts.created_at >= ?", Time.zone.now.beginning_of_day)
      .select(
        "posts.*",
        "(COALESCE(SUM(CASE WHEN votes.vote_type = TRUE THEN 1 ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN votes.vote_type = FALSE THEN 1 ELSE 0 END), 0)) AS calculated_net_votes"
      )
      .group("posts.id")

    # 2. Transformer ces posts en CarouselItem, en distinguant leur origine
    app_carousel_items = todays_posts.map do |post|
      is_system_post = post.user.email == 'deezer@system.com'
      CarouselItem.new(
        post.id,
        is_system_post ? :deezer_post : :app, # Origine: :app ou :deezer_post
        post.track&.title,
        post.track&.artist_name,
        post.track&.cover_url,
        post.track&.genres&.first&.name&.capitalize,
        post.description,
        post.user,
        post.attributes['calculated_net_votes'] || 0,
        post.created_at,
        post.track&.link_deezer,
        post.track&.preview_url,
        post
      )
    end

    # 3. Récupérer les suggestions Deezer et filtrer celles qui sont déjà des posts
    existing_deezer_track_ids_in_posts = todays_posts.map { |p| p.track.deezer_track_id }.compact

    playlist_id_top_france = 1313621735
    deezer_raw_suggestions = Rails.cache.fetch("hourly_deezer_top_france_30_tracks_v7", expires_in: 1.hour) do
      DeezerService.fetch_playlist_tracks(playlist_id: playlist_id_top_france, limit: 30)
    end
    deezer_raw_suggestions ||= []

    unique_deezer_suggestions = deezer_raw_suggestions.reject { |suggestion| existing_deezer_track_ids_in_posts.include?(suggestion.id) }

    # 4. Transformer les suggestions pures en CarouselItem
    deezer_carousel_items = unique_deezer_suggestions.map do |deezer_track|
      deezer_user = OpenStruct.new(id: 0, username: User.all.sample.username)
      CarouselItem.new(deezer_track.id, :deezer_suggestion, deezer_track.title, deezer_track.artist, deezer_track.cover_url, "Hits", nil, deezer_user, 0, Time.now, deezer_track.link_deezer, deezer_track.preview_url, nil)
    end

    # 5. Combiner et trier
    all_items = app_carousel_items + deezer_carousel_items
    @carousel_items = all_items.sort_by { |item| [-item.net_votes, -item.created_at_for_sort.to_i] }
  end
end
