require 'net/http'
require 'json'

class SearchController < ApplicationController
  def index
    if params[:query].present?
      q = params[:query]

      @results = {
        tracks: Post.joins(:track).where("tracks.title ILIKE ?", "%#{q}%").limit(10),
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
      # Recherches locales — récupérer titre + artiste
      tracks = Post.joins(:track)
                   .where("tracks.title ILIKE ?", "%#{q}%")
                   .limit(3)
                   .includes(:track)
                   .map do |post|
                     track = post.track
                     # Remplace artist_name par ta méthode ou association artiste si besoin
                     artist_name = track.artist_name rescue "Artiste inconnu"
                     "#{artist_name} - #{track.title}"
                   end

      playlists = Playlist.where("name ILIKE ?", "%#{q}%").limit(3).pluck(:name)
      users = User.where("username ILIKE ?", "%#{q}%").limit(3).pluck(:username)

      suggestions += tracks + playlists + users

      # Recherche Deezer API
      begin
        url = URI("https://api.deezer.com/search?q=#{URI.encode_www_form_component(q)}&limit=5")
        res = Net::HTTP.get_response(url)
        if res.is_a?(Net::HTTPSuccess)
          data = JSON.parse(res.body)
          deezer_titles = data["data"].map do |item|
            artist_name = item.dig("artist", "name") || "Artiste inconnu"
            "#{artist_name} - #{item['title']}"
          end
          suggestions += deezer_titles
        end
      rescue StandardError => e
        Rails.logger.error("Deezer API error in suggestions: #{e.message}")
      end

      suggestions = suggestions.uniq.first(10)
    end

    render json: suggestions
  end

  private

  def fetch_deezer_results(query)
    url = URI("https://api.deezer.com/search?q=#{URI.encode_www_form_component(query)}")
    res = Net::HTTP.get_response(url)
    if res.is_a?(Net::HTTPSuccess)
      data = JSON.parse(res.body)
      data["data"] || []
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
