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
    requested_duration_min = extract_duration_from_prompt(user_prompt)
    target_duration_ms = requested_duration_min.to_i * 60 * 1000 if requested_duration_min

    excluded_tracks_info = get_excluded_tracks_info
    curated_list = generate_curated_list_from_llm(user_prompt, excluded_tracks_info, requested_duration_min)

    if curated_list.blank?
      redirect_to new_playlist_path, alert: "L'IA n'a pas pu générer de playlist. Réessaie avec un autre prompt."
      return
    end

    selected_tracks = []
    cumulative_duration_ms = 0

    curated_list.each do |item|
      break if target_duration_ms && cumulative_duration_ms >= target_duration_ms
      next unless item['artiste'].present? && item['titre'].present?

      deezer_track = find_track_on_deezer(item['artiste'], item['titre'])
      if deezer_track
        selected_tracks << deezer_track.merge(description: item['description'])
        cumulative_duration_ms += deezer_track[:duration] if deezer_track[:duration]
      end
    end

    if selected_tracks.blank?
      redirect_to new_playlist_path, alert: "Aucun morceau trouvé sur Deezer pour cette sélection."
      return
    end

    final_duration_min = (cumulative_duration_ms / 60000.0).round
    playlist_name = generate_playlist_name(user_prompt, final_duration_min, requested_duration_min.present?)
    notice_message = "Playlist '#{playlist_name}' générée ! Durée : ~#{final_duration_min} min."

    ActiveRecord::Base.transaction do
      playlist = current_user.playlists.create!(name: playlist_name)
      create_playlist_items_with_description(playlist, selected_tracks)
      redirect_to playlist_path(playlist), notice: notice_message
    end
  rescue => e
    Rails.logger.error "[Playlist#create] Erreur : #{e.class} #{e.message}\n#{e.backtrace.join("\n")}"
    redirect_to new_playlist_path, alert: "Une erreur est survenue : #{e.message}"
  end

  private

  # Le prompt modifié pour générer un nombre de morceaux adapté à la durée demandée,
  # ou une estimation raisonnable si aucune durée n'est précisée.
  def generate_curated_list_from_llm(user_prompt, excluded_tracks = [], requested_duration_min = nil)
    excluded_list_str = excluded_tracks.empty? ? "Aucune exclusion." : excluded_tracks.map { |t| "- #{t}" }.join("\n")

    # Calcul approximatif : en moyenne un morceau dure 3.5 minutes,
    # donc on demande environ nombre_morceaux = durée / 3.5
    estimated_tracks_count = if requested_duration_min && requested_duration_min > 0
                               [(requested_duration_min / 3.5).round, 5].max
                             else
                               10 # par défaut si pas de durée demandée
                             end

    prompt = <<~PROMPT
      Tu es un expert musical spécialisé dans la curation de playlists.

      ### Objectif :
      Génère un tableau JSON strictement valide contenant environ #{estimated_tracks_count} morceaux musicaux,
      en fonction de cette demande utilisateur : "#{user_prompt}"

      ### Contraintes :
      - Fournis environ #{estimated_tracks_count} morceaux (environ, pas besoin d'être exact).
      - Chaque élément est un objet avec ces 3 clés :
        - "artiste" : le nom de l’artiste
        - "titre" : le titre du morceau
        - "description" : une courte phrase (en français) décrivant l’ambiance ou le style du morceau

      ### Interdits :
      - N'inclus **aucun** morceau déjà présent dans cette liste :
      #{excluded_list_str}

      ### Format :
      Réponds uniquement avec un tableau JSON d'objets. Aucune introduction, explication, balise ou texte en dehors du tableau JSON.

      ### Important :
      - Si la demande semble courte ou vague (ex : "jazz", "chill", "musique pour travailler"), interprète-la librement pour produire une sélection pertinente.
      - N’invoque **jamais** de message d’erreur, même si le prompt est flou.
      - Fournis toujours une sélection cohérente.

      Commence directement par `[` et termine par `]`. Ne donne rien d’autre.
    PROMPT

    begin
      chat = RubyLLM.chat
      response = chat.ask(prompt)
      raw = response.respond_to?(:content) ? response.content : response
      Rails.logger.info "[LLM RESPONSE] : #{raw}"

      json_start = raw.index("[")
      json_end = raw.rindex("]")
      return nil unless json_start && json_end

      json_str = raw[json_start..json_end]
      JSON.parse(json_str)
    rescue JSON::ParserError => e
      Rails.logger.error "[LLM PARSE ERROR] #{e.message}"
      nil
    rescue => e
      Rails.logger.error "[LLM API ERROR] #{e.class} #{e.message}"
      nil
    end
  end

  def extract_duration_from_prompt(prompt)
    return nil if prompt.blank?
    match = prompt.downcase.match(/(\d+)\s*(minutes?|mins?|h|heures?)/)
    return nil unless match
    value = match[1].to_i
    match[2].start_with?("h") ? value * 60 : value
  end

  def generate_playlist_name(user_prompt, final_duration, duration_was_requested)
    prompt = <<~PROMPT
      Propose un nom de playlist original (2 à 5 mots) pour cette demande : "#{user_prompt}".
      Ne donne que le nom, sans guillemets.
    PROMPT

    begin
      response = RubyLLM.chat.ask(prompt)
      base_name = (response.respond_to?(:content) ? response.content : response).strip.gsub('"', '')
      duration_was_requested ? "#{base_name} (#{final_duration} min)" : base_name
    rescue => e
      Rails.logger.error "[generate_playlist_name] Erreur LLM : #{e.class} #{e.message}"
      "Playlist inspirée"
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
      duration: track_data["duration"].to_i * 1000,
      preview_url: track_data["preview"],
      cover_url: track_data.dig("album", "cover_medium")
    }
  end

  def get_excluded_tracks_info
    current_user.tracks.pluck(:artist_name, :title).map { |artist, title| "#{artist} - #{title}" }
  end

  def create_playlist_items_with_description(playlist, tracks)
    tracks.each do |deezer_track|
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
