# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :set_post, only: [:show, :edit, :update]

  def show
    # @post est déjà défini par le before_action :set_post
  end

  def new
    @post = current_user.posts.build
  end

  def create
    deezer_track_id_param = params.dig(:post, :track_id)
    Rails.logger.debug "--- Post Create Action ---"
    Rails.logger.debug "Received Deezer Track ID param: #{deezer_track_id_param.inspect}" # LOG IMPORTANT

    if deezer_track_id_param.blank?
      flash.now[:alert] = "Veuillez rechercher et sélectionner un morceau avant de poster."
      @post = current_user.posts.build(description: params.dig(:post, :description))
      render :new, status: :unprocessable_entity and return
    end

    @track = Track.find_or_initialize_by(deezer_track_id: deezer_track_id_param)
    Rails.logger.debug "Track found or initialized: #{@track.persisted? ? "Persisted (ID: #{@track.id})" : 'New Record'}"

    unless @track.persisted?
      Rails.logger.debug "Track not persisted. Fetching details from Deezer for ID: #{deezer_track_id_param}" # LOG IMPORTANT
      track_data = fetch_deezer_track(deezer_track_id_param)

      unless track_data
        # C'est ici que votre message d'erreur est déclenché
        flash.now[:alert] = "Erreur lors de la récupération des infos Deezer pour le morceau (ID: #{deezer_track_id_param}). Vérifiez l'ID ou réessayez."
        @post = current_user.posts.build(description: params.dig(:post, :description))
        render :new, status: :unprocessable_entity and return
      end

      Rails.logger.debug "Successfully fetched track_data from Deezer: #{track_data.slice('id', 'title', 'artist')}"
      @track.assign_attributes(
        title: track_data["title_short"] || track_data["title"],
        artist_name: track_data["artist"]["name"],
        album_name: track_data["album"]["title"],
        preview_url: track_data["preview"],
        cover_url: track_data["album"]["cover_medium"],
        link_deezer: track_data["link"],
        duration: track_data["duration"],
        user_id: current_user.id
      )
      unless @track.save
        flash.now[:alert] = "Erreur lors de la sauvegarde des infos du morceau : #{@track.errors.full_messages.join(', ')}"
        @post = current_user.posts.build(description: params.dig(:post, :description))
        render :new, status: :unprocessable_entity and return
      end
      Rails.logger.debug "New track saved with ID: #{@track.id}"
    end

    @post = current_user.posts.build(
      track: @track,
      description: params.dig(:post, :description)
    )

    if @post.save
      Rails.logger.debug "Post created successfully with ID: #{@post.id}"
      redirect_to root_path, notice: "Post créé avec succès !"
    else
      Rails.logger.error "Failed to save post: #{@post.errors.full_messages.join(', ')}"
      flash.now[:alert] = "Erreur lors de la création du post : #{@post.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to root_path, alert: "Accès refusé" unless @post.user == current_user
  end

  def update
    unless @post.user == current_user
      redirect_to root_path, alert: "Accès refusé" and return
    end

    new_track_id = params.dig(:post, :track_id)
    current_post_description = params.dig(:post, :description)
    track_to_assign = @post.track

    if new_track_id.present? && new_track_id != @post.track.deezer_track_id.to_s
      @new_track = Track.find_or_initialize_by(deezer_track_id: new_track_id)

      unless @new_track.persisted?
        track_data = fetch_deezer_track(new_track_id)
        unless track_data
          flash.now[:alert] = "Erreur lors de la récupération des infos Deezer pour le nouveau morceau."
          render :edit, status: :unprocessable_entity and return
        end

        @new_track.assign_attributes(
          title: track_data["title_short"] || track_data["title"],
          artist_name: track_data["artist"]["name"],
          album_name: track_data["album"]["title"],
          preview_url: track_data["preview"],
          cover_url: track_data["album"]["cover_medium"],
          link_deezer: track_data["link"],
          duration: track_data["duration"],
          user_id: current_user.id
        )
        unless @new_track.save
          flash.now[:alert] = "Erreur lors de la sauvegarde du nouveau morceau : #{@new_track.errors.full_messages.join(', ')}"
          render :edit, status: :unprocessable_entity and return
        end
      end
      track_to_assign = @new_track
    end

    if @post.update(track: track_to_assign, description: current_post_description)
      redirect_to root_path, notice: "Post mis à jour avec succès !"
    else
      flash.now[:alert] = "Erreur lors de la mise à jour du post : #{@post.errors.full_messages.join(', ')}"
      render :edit, status: :unprocessable_entity
    end
  end

  def deezer_search
    query = params[:q]
    if query.blank?
      render json: { error: "La requête de recherche est vide." }, status: :bad_request and return
    end

    Rails.logger.debug "Deezer search for query: #{query}" # LOG IMPORTANT
    response = HTTParty.get("https://api.deezer.com/search", query: { q: query, limit: 10 })

    if response.success? && response.parsed_response && response.parsed_response["data"]
      results = response.parsed_response["data"].map do |track|
        {
          id: track["id"],
          title: track["title_short"] || track["title"],
          artist: track["artist"]["name"],
          preview: track["preview"],
          cover: track["album"]["cover_small"]
        }
      end
      Rails.logger.debug "Deezer search results: #{results.to_json}" # LOG IMPORTANT
      render json: results
    else
      Rails.logger.error "Deezer search failed: Code=#{response.code}, Message=#{response.message}, Body=#{response.body}" # LOG IMPORTANT
      render json: { error: "La recherche Deezer a échoué.", details: response.message }, status: response.code || 500
    end
  rescue StandardError => e
    Rails.logger.error "Deezer search internal error: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { error: "Erreur interne du serveur lors de la recherche.", details: e.message }, status: 500
  end

  private

  def set_post
    @post = Post.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Post non trouvé."
  end

  def fetch_deezer_track(track_id)
    if track_id.blank?
      Rails.logger.error "fetch_deezer_track appelé avec un track_id vide." # LOG IMPORTANT
      return nil
    end
    Rails.logger.debug "Fetching Deezer track details for ID: #{track_id}" # LOG IMPORTANT
    response = HTTParty.get("https://api.deezer.com/track/#{track_id}")

    if response.success?
      parsed = response.parsed_response
      if parsed.is_a?(Hash) && parsed["id"] # Vérifie si c'est une réponse de track valide
        Rails.logger.debug "Deezer track API success for ID #{track_id}. Data (extrait): id=#{parsed['id']}, title=#{parsed['title_short'] || parsed['title']}" # LOG IMPORTANT
        # Vérifie la clé "error" spécifique de Deezer DANS une réponse réussie
        if parsed["error"]
            Rails.logger.warn "Deezer API returned an error in a successful response for track ID #{track_id}: #{parsed['error']}" # LOG IMPORTANT
            return nil # Si Deezer dit qu'il y a une erreur, on considère que c'est un échec
        end
        return parsed # Pas d'erreur Deezer, on retourne les données
      else
        Rails.logger.error "Réponse Deezer inattendue (pas un Hash valide ou pas d'ID de morceau) pour track #{track_id}: #{parsed.inspect}" # LOG IMPORTANT
      end
    else
      Rails.logger.error "Deezer API Error (HTTParty) for track #{track_id}: Code=#{response.code}, Message=#{response.message}, Body=#{response.body}" # LOG IMPORTANT
    end
    nil # Retourne nil si l'appel échoue ou si Deezer retourne une erreur
  end
end
