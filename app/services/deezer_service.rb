# app/services/deezer_service.rb
require 'httparty'
require 'ostruct'

class DeezerService
  include HTTParty
  base_uri 'https://api.deezer.com'

  # playlist_id par défaut est moins important si on le passe toujours depuis le controller
  def self.fetch_playlist_tracks(playlist_id: 1313621735, limit: 30) # Limite par défaut à 30
    Rails.logger.info "DeezerService: Fetching playlist ID #{playlist_id} with limit #{limit}"
    response = get("/playlist/#{playlist_id}/tracks", query: { limit: limit, index: 0 })

    if response.success? && response.parsed_response["data"]
      Rails.logger.info "DeezerService: Successfully fetched #{response.parsed_response['data'].length} tracks."
      response.parsed_response["data"].map do |track_data|
        OpenStruct.new(
          id: track_data["id"],
          title: track_data["title_short"] || track_data["title"],
          artist: track_data["artist"]["name"],
          cover_url: track_data["album"]["cover_medium"],
          # Le genre ici est un fallback, le contrôleur peut le surcharger.
          # Pour une playlist "Top", il est difficile d'assigner un genre unique ici.
          genre: track_data.dig("album", "genres", "data", 0, "name") || "Musique", # Essaye de prendre le premier genre de l'album
          link_deezer: track_data["link"],
          preview_url: track_data["preview"]
        )
      end
    else
      Rails.logger.error "DeezerService API Error (Playlist Tracks): #{response.code} - #{response.message}. Body: #{response.body}"
      []
    end
  rescue HTTParty::Error => e
    Rails.logger.error "DeezerService HTTParty Error (Playlist Tracks): #{e.message}"
    []
  rescue StandardError => e
    Rails.logger.error "DeezerService Service Error (Playlist Tracks): #{e.message}"
    []
  end

  def self.fetch_track(track_id)
    Rails.logger.info "DeezerService: Fetching single track ID #{track_id}"
    response = get("/track/#{track_id}")

    if response.success? && response.parsed_response
      track_data = response.parsed_response
      if track_data["error"]
        Rails.logger.error "DeezerService API Error (Single Track): #{track_data['error']['message']}"
        return nil
      end
      # On retourne juste l'URL de l'aperçu, c'est tout ce dont on a besoin pour l'instant
      return track_data["preview"]
    else
      Rails.logger.error "DeezerService API Error (Single Track): #{response.code} - #{response.message}. Body: #{response.body}"
      nil
    end
  rescue HTTParty::Error => e
    Rails.logger.error "DeezerService HTTParty Error (Single Track): #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "DeezerService Service Error (Single Track): #{e.message}"
    nil
  end
end
