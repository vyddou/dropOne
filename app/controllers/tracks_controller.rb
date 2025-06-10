class TracksController < ApplicationController
  before_action :authenticate_user!

  def preview
    track = Track.find(params[:id])
    deezer_track_id = track.deezer_track_id

    if deezer_track_id.blank?
      render json: { error: 'Deezer track ID not found' }, status: :not_found
      return
    end

    fresh_url = DeezerService.fetch_track(deezer_track_id)

    if fresh_url
      # On met à jour la base de données avec l'URL fraîche.
      # Cela peut bénéficier à d'autres utilisateurs et réduit les appels API.
      track.update(preview_url: fresh_url)
      render json: { preview_url: fresh_url }
    else
      render json: { error: 'Preview not available from Deezer' }, status: :not_found
    end
  end
end