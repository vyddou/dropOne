require 'net/http'
require 'json'

class SearchController < ApplicationController
  def index
    if params[:query].present?
      q = params[:query]

      @results = {
        tracks: Post.joins(:track).includes(:track).where("tracks.title ILIKE ?", "%#{q}%").limit(10),
        playlists: Playlist.where("name ILIKE ?", "%#{q}%").limit(10),
        users: User.where("username ILIKE ?", "%#{q}%").limit(10)
      }

      @deezer_results = fetch_deezer_results(q)
    else
      @results = { tracks: [], playlists: [], users: [] }
      @deezer_results = []
    end
  end

  def suggestions
    q = params[:query]
    suggestions = []

    if q.present?
      tracks = Post.joins(:track).includes(:track)
                   .where("tracks.title ILIKE ?", "%#{q}%")
                   .limit(3)
                   .map do |post|
        track = post.track
        artist_name = track.artist_name rescue "Artiste inconnu"
        {
          type: "track",
          label: "#{artist_name} - #{track.title}",
          image_url: track.cover_url || "/images/default_cover.png"
        }
      end

      playlists = Playlist.where("name ILIKE ?", "%#{q}%").limit(3).map do |playlist|
        {
          type: "playlist",
          label: playlist.name,
          image_url: "/images/black_placeholder.png"
        }
      end

      users = User.where("username ILIKE ?", "%#{q}%").limit(3).map do |user|
        {
          type: "user",
          label: user.username,
          image_url: user.profile_photo_url || "/images/default_user_avatar.png"
        }
      end

      suggestions += tracks + playlists + users

      begin
        url = URI("https://api.deezer.com/search?q=#{URI.encode_www_form_component(q)}&limit=5")
        res = Net::HTTP.get_response(url)
        if res.is_a?(Net::HTTPSuccess)
          data = JSON.parse(res.body)
          deezer_titles = data["data"].map do |item|
            {
              type: "deezer",
              label: "#{item.dig('artist', 'name') || 'Artiste inconnu'} - #{item['title']}",
              image_url: item.dig("album", "cover_small") || "/images/default_cover.png",
              preview: item["preview"]  # ajout de l'URL de l'extrait
            }
          end
          suggestions += deezer_titles
        end
      rescue StandardError => e
        Rails.logger.error("Deezer API error in suggestions: #{e.message}")
      end

      suggestions.uniq! { |s| s[:label] }
      suggestions = suggestions.first(10)
    end

    render json: suggestions
  end

  private

  def fetch_deezer_results(query)
    url = URI("https://api.deezer.com/search?q=#{URI.encode_www_form_component(query)}")
    res = Net::HTTP.get_response(url)
    if res.is_a?(Net::HTTPSuccess)
      data = JSON.parse(res.body)
      data["data"].map do |item|
        {
          "id" => item["id"],
          "title" => item["title"],
          "artist" => item["artist"],
          "album" => item["album"],
          "link" => item["link"],
          "preview" => item["preview"]  # ajout de l'URL preview ici aussi
        }
      end
    else
      Rails.logger.error("Deezer API error: #{res.code} - #{res.body}")
      flash.now[:alert] = "Erreur lors de la recherche Deezer"
      []
    end
  rescue StandardError => e
    Rails.logger.error("Exception Deezer API: #{e.message}")
    flash.now[:alert] = "Erreur lors de la recherche Deezer"
    []
  end
end
