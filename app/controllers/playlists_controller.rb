class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  require 'net/http'
  require 'uri'
  require 'json'
  require 'set'

  def index
    @playlists = current_user.playlists
                             .where.not(name: [Playlist::LIKE_PLAYLIST_NAME, Playlist::DISLIKE_PLAYLIST_NAME])
                             .order(created_at: :desc)
  end

  def show
    @playlist = current_user.playlists.find(params[:id])
    @playlist_items = @playlist.playlist_items.includes(:track)
  end

  def new
    @playlist = Playlist.new
  end

  def destroy
    playlist = current_user.playlists.find(params[:id])
    playlist.destroy
    redirect_to playlists_path, notice: "Playlist supprimée."
  end

  def rename
    @playlist = current_user.playlists.find(params[:id])
    if @playlist.update(name: params[:playlist][:name])
      redirect_to @playlist, notice: 'Playlist renommée avec succès.'
    else
      redirect_to @playlist, alert: 'Erreur lors du renommage de la playlist.'
    end
  end

  def create
    user_provided_prompt = params[:user_prompt].to_s.strip
    Rails.logger.debug "[Playlist#create] user_provided_prompt: #{user_provided_prompt.inspect}"

    excluded_deezer_track_ids = excluded_track_ids
    Rails.logger.debug "[Playlist#create] excluded_deezer_track_ids (#{excluded_deezer_track_ids.size}): #{excluded_deezer_track_ids.join(', ')}"

    total_duration_minutes = extract_duration_from_prompt(user_provided_prompt) || 15
    total_duration_ms = total_duration_minutes * 60_000

    search_query = generate_search_query(user_provided_prompt)
    Rails.logger.debug "[Playlist#create] search_query: #{search_query.inspect}"

    all_tracks = fetch_deezer_tracks_with_fallback(search_query, excluded_deezer_track_ids, 100, max_retries: 5)

    selected_tracks = []
    cumulative_duration = 0
    artist_counts = Hash.new(0)

    all_tracks.each do |track|
      break if cumulative_duration >= total_duration_ms
      next unless track[:duration].present?
      next if artist_counts[track[:artist_name].downcase] >= 2

      selected_tracks << track
      cumulative_duration += track[:duration]
      artist_counts[track[:artist_name].downcase] += 1
    end

    if selected_tracks.blank?
      Rails.logger.warn "[Playlist#create] Aucun morceau sélectionné pour la durée #{total_duration_minutes} min"
      redirect_to new_playlist_path, alert: "Aucun morceau n'a pu être trouvé pour votre demande."
      return
    end

    message = if cumulative_duration < total_duration_ms
                "La playlist générée atteint #{(cumulative_duration / 60_000.0).round(1)} minutes, soit moins que les #{total_duration_minutes} demandées."
              else
                "Playlist générée avec succès !"
              end

    playlist_name = generate_playlist_name(user_provided_prompt, total_duration_minutes)

    ActiveRecord::Base.transaction do
      playlist = current_user.playlists.create!(name: playlist_name)
      create_playlist_tracks(playlist, selected_tracks)
      redirect_to playlist_path(playlist), notice: message
    end
  rescue => e
    Rails.logger.error "[Playlist#create] Échec de la génération : #{e.class} #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to new_playlist_path, alert: "Échec de la génération : #{e.message}"
  end

  private

  def generate_search_query(user_prompt = nil)
    style_list = %w[
      Pop Rap Rock Jazz Blues Classical Electro Metal Funk Soul Disco Reggae Dancehall
      RnB House Techno Trance Chillout Ambient Dub K-pop J-pop Afrobeat Salsa Reggaeton
      Trap Grime Drill Country Folk Punk Gospel New\ Wave Indie\ Rock Hard\ Rock Synthwave
      Lofi World\ Music
    ].join(', ')

    base_prompt = <<~PROMPT
      Tu es un expert en musique et en classification musicale.

      À partir de cette demande utilisateur :
      "#{user_prompt}"

      Ta tâche est de générer une requête musicale très précise pour une recherche sur Deezer.

      ### Contraintes :
      - Ne donne que la requête. Aucune explication, aucun commentaire.
      - Inclue obligatoirement un style musical clair parmi ceux disponibles sur Deezer.
      - La requête doit être courte (3 à 6 mots), et contenir si possible une époque (ex: années 90) ou un adjectif d’ambiance (ex: mélancolique, chill, énervé, joyeux).
      - N'invente pas de genre.
      - Ne propose jamais un style qui mélange plusieurs genres non compatibles.
      - Ne cite jamais d’artiste sauf si l’utilisateur le fait explicitement.
      - Si la durée est mentionnée (ex: "30 min"), prends-la en compte comme objectif, mais ne l'inclus pas dans la requête.

      Liste de styles valides (Deezer) : #{style_list}

      Donne uniquement la requête finale.
    PROMPT

    chat = RubyLLM.chat
    response = chat.ask(base_prompt)
    query = response.respond_to?(:content) ? response.content : response
    query.strip.downcase.gsub(/["']/, '').presence || fallback_query
  rescue => e
    Rails.logger.error "[generate_search_query] LLM Error: #{e.class} #{e.message}"
    fallback_query
  end

  def fallback_query
    ['jazz', 'pop', 'rock', 'electro', 'indie', 'chill'].sample(2).join(' ')
  end

  def fetch_deezer_tracks_with_fallback(query, excluded_ids, desired_number = 100, max_retries: 3)
    retries = 0
    tracks = []
    seen_tracks = Set.new

    while tracks.size < desired_number && retries < max_retries
      url = URI("https://api.deezer.com/search?q=#{URI.encode_www_form_component(query)}&limit=50")
      response = Net::HTTP.get(url)
      results = JSON.parse(response)["data"] || []

      results.each do |t|
        next if excluded_ids.include?(t["id"])
        key = [t["title"].downcase.strip, t["artist"]["name"].downcase.strip]
        next if seen_tracks.include?(key)

        tracks << {
          id: t["id"],
          title: t["title"],
          artist_name: t["artist"]["name"],
          duration: t["duration"] * 1000,
          preview_url: t["preview"],
          cover_url: t.dig("album", "cover_medium")
        }
        seen_tracks << key
        break if tracks.size >= desired_number
      end

      if results.empty? && tracks.size < desired_number
        query = fallback_query
      end

      retries += 1
    end

    tracks.first(desired_number)
  end

  def excluded_track_ids
    current_user.playlists
                .joins(playlist_items: :track)
                .pluck('tracks.deezer_track_id')
                .uniq
  end

  def create_playlist_tracks(playlist, tracks)
    tracks.map do |deezer_track|
      track = Track.find_or_initialize_by(deezer_track_id: deezer_track[:id]).tap do |t|
        t.title = deezer_track[:title]
        t.artist_name = deezer_track[:artist_name]
        t.duration = deezer_track[:duration]
        t.preview_url = deezer_track[:preview_url]
        t.cover_url = deezer_track[:cover_url]
        t.user_id = playlist.user_id
        t.link_deezer = "https://www.deezer.com/track/#{deezer_track[:id]}"
        t.save!
      end
      playlist.playlist_items.create!(track: track)
    end
  end

  def extract_duration_from_prompt(prompt)
    return nil if prompt.blank?
    duration_match = prompt.downcase.match(/(\d+)\s*(minutes?|mins?|h|heures?|hours?)/)
    return nil unless duration_match
    value = duration_match[1].to_i
    unit = duration_match[2]
    unit =~ /h|heures?|hours?/ ? value * 60 : value
  end

  def generate_playlist_name(user_prompt, total_duration_minutes)
    duration_text = "(#{total_duration_minutes} min)"
    return "Ma Playlist #{Time.current.strftime('%d/%m/%Y %H:%M')} #{duration_text}" if user_prompt.blank?

    prompt = <<~PROMPT
      Résume en quelques mots (3 à 8) ce sujet de manière concise et musicale :
      "#{user_prompt}"
      Donne uniquement le résumé, sans explication, avec éventuellement des emojis si pertinent.
    PROMPT

    begin
      response = RubyLLM.chat.ask(prompt)
      summary = response.respond_to?(:content) ? response.content : response
      summary = summary.capitalize
      summary.match?(/\b\d+\s*(min|minutes|h|heures?)\b/i) ? summary : "#{summary} #{duration_text}"
    rescue => e
      Rails.logger.error "[generate_playlist_name] LLM Error: #{e.class} #{e.message}"
      "Ma Playlist #{Time.current.strftime('%d/%m/%Y %H:%M')} #{duration_text}"
    end
  end
end
