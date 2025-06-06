class PlaylistsController < ApplicationController
  before_action :authenticate_user!
  require 'net/http'
  require 'uri'
  require 'json'

  def index
    @playlists = current_user.playlists
                             .where.not(name: [Playlist::LIKE_PLAYLIST_NAME, Playlist::DISLIKE_PLAYLIST_NAME])
                             .order(created_at: :desc)
  end

  def show
    # Utiliser find_by pour éviter une erreur si la playlist n'existe pas
    @playlist = Playlist.find_by(id: params[:id])
    if @playlist.nil?
      redirect_to playlists_path, alert: "Playlist non trouvée."
      return
    end
    @playlist_items = @playlist.playlist_items.includes(:track)
  end

  def new
    @playlist = Playlist.new
  end

  def destroy
    @playlist = current_user.playlists.find(params[:id])
    @playlist.destroy
    respond_to do |format|
      format.html { redirect_to request.referer || user_path(current_user), notice: "Playlist supprimée" }
      format.turbo_stream { render turbo_stream: turbo_stream.remove("playlist_#{params[:id]}") }
    end
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
    user_prompt = params[:user_prompt].to_s.strip
    Rails.logger.debug "[Playlist#create] Démarrage avec le prompt : #{user_prompt}"

    requested_duration_min = extract_duration_from_prompt(user_prompt)
    target_duration_ms = requested_duration_min * 60 * 1000 if requested_duration_min

    excluded_tracks_info = get_excluded_tracks_info
    curated_list = generate_curated_list_from_llm(user_prompt, excluded_tracks_info)

    if curated_list.blank?
      redirect_to new_playlist_path, alert: "L'IA n'a pas pu générer de playlist. Essayez d'être plus précis."
      return
    end

    selected_tracks = []
    cumulative_duration_ms = 0

    curated_list.each do |item|
      # Si une durée est demandée et atteinte, on arrête.
      if target_duration_ms && cumulative_duration_ms >= target_duration_ms
        Rails.logger.info "[Playlist#create] Durée cible de #{requested_duration_min} min atteinte. Arrêt de l'ajout."
        break
      end

      next unless item['artiste'].present? && item['titre'].present?

      deezer_track = find_track_on_deezer(item['artiste'], item['titre'])
      if deezer_track
        selected_tracks << deezer_track.merge(description: item['description'])
        cumulative_duration_ms += deezer_track[:duration] if deezer_track[:duration]
      else
        Rails.logger.warn "[Playlist#create] Morceau suggéré non trouvé : #{item['artiste']} - #{item['titre']}"
      end
    end

    if selected_tracks.blank?
      redirect_to new_playlist_path, alert: "Aucun des morceaux suggérés n'a pu être trouvé sur Deezer."
      return
    end

    final_duration_min = (cumulative_duration_ms / 60000.0).round
    playlist_name = generate_playlist_name(user_prompt, final_duration_min, requested_duration_min.present?)
    notice_message = "Playlist '#{playlist_name}' générée ! Durée d'environ #{final_duration_min} min."

    ActiveRecord::Base.transaction do
      playlist = current_user.playlists.create!(name: playlist_name)
      create_playlist_items_with_description(playlist, selected_tracks)
      redirect_to playlist_path(playlist), notice: notice_message
    end
  rescue => e
    Rails.logger.error "[Playlist#create] Échec : #{e.class} #{e.message}\n#{e.backtrace.join("\n")}"
    redirect_to new_playlist_path, alert: "Une erreur est survenue : #{e.message}"
  end

  private

  def generate_curated_list_from_llm(user_prompt, excluded_tracks = [])
    excluded_list_str = excluded_tracks.empty? ? "Aucun." : excluded_tracks.join("\n- ")

    prompt = <<~PROMPT
      Tu es un expert musical qui répond UNIQUEMENT avec du JSON.
      Ta tâche est de créer une liste de suggestions de morceaux basée sur la demande suivante : "#{user_prompt}"

      ### Consignes IMPÉRATIVES :
      1. Tu DOIS générer une liste de **25 morceaux**. C'est une consigne stricte. Même si la demande semble simple, fournis une liste riche et variée de 25 titres.
      2. Pour chaque morceau, fournis les clés "artiste", "titre", et "description" (1 phrase en français).
      3. **Exclusion** : Ne suggère PAS les morceaux suivants :
      - #{excluded_list_str}
      4. **Formatage OBLIGATOIRE** : Ta réponse doit être un objet JSON valide, et RIEN D'AUTRE. Elle doit commencer par `[` et se terminer par `]`.
    PROMPT

    begin
      chat = RubyLLM.chat
      response = chat.ask(prompt)
      raw_content = response.respond_to?(:content) ? response.content : response
      Rails.logger.info "[LLM RAW RESPONSE]:\n#{raw_content}"
      json_match = raw_content.match(/(\[.*\]|\{.*\})/m)
      return nil unless json_match
      JSON.parse(json_match[1])
    rescue JSON::ParserError => e
      Rails.logger.error "[LLM PARSING] Erreur de parsing: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "[LLM API] Erreur: #{e.class} #{e.message}"
      nil
    end
  end

  def extract_duration_from_prompt(prompt)
    return nil if prompt.blank?
    duration_match = prompt.downcase.match(/(\d+)\s*(minutes?|mins?|h|heures?)/)
    return nil unless duration_match
    value = duration_match[1].to_i
    unit = duration_match[2]
    unit.start_with?('h') ? value * 60 : value
  end

  def generate_playlist_name(user_prompt, final_duration, duration_was_requested)
    prompt = <<~PROMPT
      Génère un nom de playlist créatif (2 à 5 mots) pour la demande : "#{user_prompt}".
      Ne donne que le nom, sans guillemets.
    PROMPT

    begin
      response = RubyLLM.chat.ask(prompt)
      base_name = (response.respond_to?(:content) ? response.content : response).strip.gsub('"', '')
      # On n'ajoute la durée au nom que si l'utilisateur l'a demandée
      duration_was_requested ? "#{base_name} (#{final_duration} min)" : base_name
    rescue => e
      Rails.logger.error "[generate_playlist_name] LLM Error: #{e.class} #{e.message}"
      "Playlist Inspirée"
    end
  end

  def find_track_on_deezer(artist, title)
    query = "artist:\"#{artist.gsub('"', '')}\" track:\"#{title.gsub('"', '')}\""
    url = URI("https://api.deezer.com/search?q=#{URI.encode_www_form_component(query)}&limit=1")

    response = Net::HTTP.get(url)
    results = JSON.parse(response)["data"] || []
    return nil if results.empty?

    track_data = results.first
    {
      id: track_data["id"],
      title: track_data["title"],
      artist_name: track_data.dig("artist", "name"),
      duration: track_data.dig("duration").to_i * 1000,
      preview_url: track_data["preview"],
      cover_url: track_data.dig("album", "cover_medium")
    }
  end

  def get_excluded_tracks_info
    current_user.tracks.pluck(:artist_name, :title).map { |artist, title| "#{artist} - #{title}" }
  end

  def create_playlist_items_with_description(playlist, tracks_with_descriptions)
    tracks_with_descriptions.each do |deezer_track|
      track = Track.find_or_create_by!(deezer_track_id: deezer_track[:id]) do |t|
        t.title = deezer_track[:title]
        t.artist_name = deezer_track[:artist_name]
        t.duration = deezer_track[:duration]
        t.preview_url = deezer_track[:preview_url]
        t.cover_url = deezer_track[:cover_url]
        t.user_id = playlist.user_id
        t.link_deezer = "https://www.deezer.com/track/#{deezer_track[:id]}"
      end
      playlist.playlist_items.create!(track: track, description: deezer_track[:description])
    end
  end
end
