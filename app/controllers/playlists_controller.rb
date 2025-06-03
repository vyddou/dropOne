class PlaylistsController < ApplicationController
  before_action :authenticate_user!

  # Affiche les playlists de l'utilisateur, sauf celles de like/dislike
  def index
    @playlists = current_user.playlists
                             .where.not(name: [Playlist::LIKE_PLAYLIST_NAME, Playlist::DISLIKE_PLAYLIST_NAME])
                             .order(created_at: :desc)
  end

  # Affiche une playlist et ses morceaux
  def show
    @playlist = current_user.playlists.find(params[:id])
    @playlist_items = @playlist.playlist_items.includes(:track)
  end

  # Formulaire nouvelle playlist
  def new
    @playlist = Playlist.new
  end

  # Suppression d'une playlist
  def destroy
    playlist = current_user.playlists.find(params[:id])
    playlist.destroy
    redirect_to playlists_path, notice: "Playlist supprimée."
  end

  # Renommage d'une playlist
  def rename
    @playlist = current_user.playlists.find(params[:id])
    if @playlist.update(name: params[:playlist][:name])
      redirect_to @playlist, notice: 'Playlist renommée avec succès.'
    else
      redirect_to @playlist, alert: 'Erreur lors du renommage de la playlist.'
    end
  end

  # Création d'une playlist générée automatiquement
  def create
    user_provided_prompt = params[:user_prompt].to_s.strip
    Rails.logger.debug "[Playlist#create] user_provided_prompt: #{user_provided_prompt.inspect}"

    excluded_deezer_track_ids = excluded_track_ids
    Rails.logger.debug "[Playlist#create] excluded_deezer_track_ids (#{excluded_deezer_track_ids.size}): #{excluded_deezer_track_ids.join(', ')}"

    total_duration_minutes = extract_duration_from_prompt(user_provided_prompt) || 15
    total_duration_ms = total_duration_minutes * 60_000

    search_query = generate_search_query(user_provided_prompt)
    Rails.logger.debug "[Playlist#create] search_query: #{search_query.inspect}"

    all_tracks = fetch_tracks_with_fallback(search_query, excluded_deezer_track_ids, 100, max_retries: 5)

    selected_tracks = []
    cumulative_duration = 0

    all_tracks.each do |track|
      break if cumulative_duration >= total_duration_ms

      # Ignore les tracks sans durée définie (par sécurité)
      next unless track.duration_ms.present?

      selected_tracks << track
      cumulative_duration += track.duration_ms
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
      # raise
      playlist = current_user.playlists.create!(
        # generated_at: Time.current,
        # user_id: current_user,
        name: playlist_name
      )
      create_playlist_tracks(playlist, selected_tracks).each do |pt|
        Rails.logger.debug "[Playlist#create] Ajout Track ##{pt.track_id} à Playlist ##{playlist.id}"
      end
      redirect_to playlist_path(playlist), notice: message
    end
  rescue => e
    Rails.logger.error "[Playlist#create] Échec de la génération : #{e.class} #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to new_playlist_path, alert: "Échec de la génération : #{e.message}"
  end


  private

  def generate_search_query(user_prompt = nil)
    prompt_for_llm = if user_prompt.present?
      <<~PROMPT
        Extrait 1 à 5 mots-clés pertinents pour une recherche musicale à partir du texte suivant.
        Texte de l'utilisateur : "#{user_prompt}"
        Donne uniquement les mots-clés, sans explication.
        Par contre attention on ne veut aucun doublon de morceaux ni d'artiste
      PROMPT
    else
      <<~PROMPT
        Génère une requête de recherche musicale courte et pertinente en 1 à 3 mots-clés.
        Donne uniquement la requête, sans explication.
        Par contre attention on ne veut aucun doublon de morceaux ni d'artiste
      PROMPT
    end

    begin
      chat = RubyLLM.chat
      response = chat.ask(prompt_for_llm)
      query = response.respond_to?(:content) ? response.content : response
      query = query.strip.downcase.gsub(/["']/, '')
      Rails.logger.info "[Playlist#create] LLM generated search query: #{query.inspect}"
      query.presence || fallback_query
    rescue => e
      Rails.logger.error "[Playlist#create] LLM Error: #{e.class} #{e.message}"
      fallback_query
    end
  end

  def fallback_query
    ['jazz', 'pop', 'rock', 'electronic', 'indie', 'lofi', 'chill'].sample(2).join(' ')
  end

  # Recherche de morceaux avec tentative de fallback si résultats insuffisants
  def fetch_tracks_with_fallback(query, excluded_ids, desired_number = 100, max_retries: 3)
    
    retries = 0
    tracks = []
    seen = Set.new
    current_query = query.dup

    while tracks.size < desired_number && retries < max_retries
      search_results = RSpotify::Track.search(current_query, limit: 50, market: 'FR')
      
      filtered = search_results.reject do |t|
        # Normalisation pour éviter les doublons sur nom + artistes
        key = [t.name.downcase.strip, t.artists.map(&:name).join(',').downcase.strip]
        excluded_ids.include?(t.id) || seen.include?(key)
      end

      filtered.each do |t|
        break if tracks.size >= desired_number
        key = [t.name.downcase.strip, t.artists.map(&:name).join(',').downcase.strip]
        
        unless seen.include?(key)
          tracks << t
          seen << key
        end
      end

      if filtered.empty? && tracks.size < desired_number
        Rails.logger.info "[Playlist#create] Fallback query activated for '#{current_query}'"
        current_query = fallback_query
      end

      retries += 1
    end

    tracks.first(desired_number)
  end


  def excluded_track_ids
   current_user.playlists
                .joins(playlist_items: :track)
                # .pluck('tracks.deezer_track_id')
                .uniq
  end

  # --- Intégration Deezer pour preview alternative ---
  require 'net/http'
  require 'uri'
  require 'json'

  def fetch_deezer_preview(track_title, artist_name)
    query = URI.encode_www_form_component("track:\"#{track_title}\" artist:\"#{artist_name}\"")
    url = URI("https://api.deezer.com/search?q=#{query}&limit=1")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)
    if data["data"] && data["data"].any?
      return data["data"][0]["preview"] # 30s mp3
    else
      return nil
    end
  rescue => e
    Rails.logger.error("[Deezer] Error fetching preview: #{e.message}")
    nil
  end

  # Création des morceaux et ajout à la playlist, avec preview Deezer si disponible
  def create_playlist_tracks(playlist, tracks)
    Rails.logger.debug "Creating PlaylistItem with playlist.user_id = #{playlist.user_id}"

    tracks.map do |spotify_track|
      track = Track.find_or_initialize_by(deezer_track_id: spotify_track.id).tap do |t|
        # raise
        t.title = spotify_track.name
        t.artist_name = spotify_track.artists.map(&:name).join(', ')
        t.duration = spotify_track.duration_ms
        t.preview_url = spotify_track.preview_url
        t.user_id = playlist.user_id
        deezer_preview = fetch_deezer_preview(t.title, t.artist_name)
        t.link_deezer = deezer_preview if deezer_preview.present?

        t.save!
      end
      playlist.playlist_items.create!(track: track)
    end
  end

  # Extraction durée depuis prompt utilisateur (ex: "20 minutes", "1h", etc.)
  def extract_duration_from_prompt(prompt)
    return nil if prompt.blank?

    duration_match = prompt.downcase.match(/(\d+)\s*(minutes?|mins?|h|heures?|hours?)/)
    return nil unless duration_match

    value = duration_match[1].to_i
    unit = duration_match[2]

    case unit
    when /h|heures?|hours?/ then value * 60
    else value
    end
  end

  def generate_playlist_name(user_prompt, total_duration_minutes)
    duration_text = "(#{total_duration_minutes} min)"

    return "Ma Playlist #{Time.current.strftime('%d/%m/%Y %H:%M')} #{duration_text}" if user_prompt.blank?

    prompt = <<~PROMPT
      Résume en quelques mots (de 3 à 8 maximum) ce sujet de manière concise et musicale :
      "#{user_prompt}"
      Donne uniquement le résumé, sans explication mais avec des emoticones (pas seul) si pertinent.
    PROMPT

    begin
      response = RubyLLM.chat.ask(prompt)
      summary = response.respond_to?(:content) ? response.content : response
      # summary = summary.strip.gsub(/[^\w\s]/, '').split.take(5).join(' ')
      summary = summary.capitalize

      # Si la durée semble déjà présente dans le résumé, on l'ajoute pas
      if summary.match?(/\b\d+\s*(min|minutes|h|heures?)\b/i)
        summary
      else
        "#{summary} #{duration_text}"
      end
    rescue => e
      Rails.logger.error "[generate_playlist_name] LLM Error: #{e.class} #{e.message}"
      "Ma Playlist #{Time.current.strftime('%d/%m/%Y %H:%M')} #{duration_text}"
    end
  end

end
