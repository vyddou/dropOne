# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  def home
    # On ne récupère que les posts du jour créés par de vrais utilisateurs
    # et on les trie directement par score.
    @todays_posts = Post
      .left_joins(:votes)
      .includes(:track, :user, :comments, track: :genres) # Eager load pour la performance
      .where("posts.created_at >= ?", Time.zone.now.beginning_of_day)
      .select(
        "posts.*",
        "(COALESCE(SUM(CASE WHEN votes.vote_type = TRUE THEN 1 ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN votes.vote_type = FALSE THEN 1 ELSE 0 END), 0)) AS net_votes"
      )
      .group("posts.id")
      .order("net_votes DESC, posts.created_at DESC") # Trie par score, puis par date
  rescue StandardError => e
    Rails.logger.error "ERREUR dans PagesController#home: #{e.message}"
    @todays_posts = [] # En cas d'erreur, on initialise un tableau vide pour éviter que la vue ne plante
  end
end
