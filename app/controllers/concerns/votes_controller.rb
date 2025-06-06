# app/controllers/votes_controller.rb
class VotesController < ApplicationController
  before_action :authenticate_user! # Seuls les utilisateurs connectés peuvent voter

  def create
    deezer_track_id = params[:track_id]
    vote_type = params[:vote_type]

    # 1. Trouver ou créer le Track dans notre DB
    track = Track.find_or_create_by(deezer_track_id: deezer_track_id) do |t|
      track_data = fetch_deezer_track(deezer_track_id)
      # Si on ne trouve pas le morceau sur Deezer, on arrête
      unless track_data
        flash[:alert] = "Impossible de trouver les informations pour ce morceau."
        return redirect_back(fallback_location: root_path)
      end
      t.assign_attributes(
        title: track_data["title_short"] || track_data["title"],
        artist_name: track_data["artist"]["name"],
        album_name: track_data["album"]["title"],
        preview_url: track_data["preview"],
        cover_url: track_data["album"]["cover_medium"],
        link_deezer: track_data["link"],
        duration: track_data["duration"],
        user_id: current_user.id # Le premier à voter "découvre" le track
      )
    end

    unless track.persisted?
      flash[:alert] = "Erreur lors de la sauvegarde du morceau."
      return redirect_back(fallback_location: root_path)
    end

    # 2. Trouver ou créer le Post du jour pour ce Track
    # Si le post n'existe pas, il est créé et appartient à l'utilisateur système "Deezer"
    # Cela garantit qu'il n'y a qu'un seul "post" par morceau par jour.

    post_user = User.find_by(username: params[:user])
    post = Post.find_or_create_by(track: track, created_at: Time.zone.today.all_day) do |p|
      p.user = post_user
      p.description = "Suggéré par la communauté."
    end

    # 3. Appliquer le vote de l'utilisateur actuel sur ce Post
    is_hot_vote = vote_type == 'hot'
    existing_vote = post.votes.find_by(user: current_user)

    if existing_vote
      if existing_vote.vote_type == is_hot_vote
        existing_vote.destroy
        flash[:notice] = "Vote annulé."
      else
        existing_vote.update(vote_type: is_hot_vote)
        flash[:notice] = "Vote mis à jour."
      end
    else
      new_vote = post.votes.build(user: current_user, vote_type: is_hot_vote)
      if new_vote.save
        flash[:notice] = "Vote enregistré !"
      else
        flash[:alert] = "Impossible d'enregistrer le vote."
      end
    end

    redirect_back fallback_location: root_path
  end

  private

  def fetch_deezer_track(track_id)
    return nil if track_id.blank?
    response = HTTParty.get("https://api.deezer.com/track/#{track_id}")
    return nil unless response.success?
    parsed = response.parsed_response
    parsed if parsed.is_a?(Hash) && parsed["id"] && !parsed["error"]
  end
end
