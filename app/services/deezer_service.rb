# app/services/deezer_service.rb
require 'httparty'
require 'ostruct' # Pour créer des objets flexibles facilement

class DeezerService
  include HTTParty
  base_uri 'https://api.deezer.com'

  # Récupère les morceaux d'une playlist Deezer (par défaut "Hits du Moment France")
  # id d'une playlist publique , flaflamobile tu peux nous mettre une playslist metal si tu veux
  def self.fetch_playlist_tracks(playlist_id: 1111141961, limit: 5)
    response = get("/playlist/#{playlist_id}/tracks", query: { limit: limit, index: 0 })

    if response.success? && response.parsed_response["data"]
      response.parsed_response["data"].map do |track_data|
        # Nous créons un OpenStruct pour que l'objet ressemble à ce que votre vue attend
        # pour un 'track' (avec cover_url, title, artist, genre, link_deezer).
        OpenStruct.new(
          id: track_data["id"], # ID Deezer du morceau
          title: track_data["title_short"] || track_data["title"],
          artist: track_data["artist"]["name"],
          cover_url: track_data["album"]["cover_medium"], # Ou track_data["album"]["cover_big"] pour une meilleure qualité
          genre: "Pop / Variété", # Placeholder, car le genre exact par morceau est complexe à obtenir efficacement ici.
                                # Vous pourriez utiliser le genre principal de la playlist si elle est thématique.
          link_deezer: track_data["link"] # Lien direct vers le morceau sur Deezer
        )
      end
    else
      Rails.logger.error "Deezer API Error (Playlist Tracks): #{response.code} - #{response.message}"
      [] # Retourne un tableau vide en cas d'erreur pour ne pas planter la page
    end
  rescue HTTParty::Error => e
    Rails.logger.error "Deezer HTTParty Error (Playlist Tracks): #{e.message}"
    []
  rescue StandardError => e
    Rails.logger.error "Deezer Service Error (Playlist Tracks): #{e.message}"
    []
  end
end
