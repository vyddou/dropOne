# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  before_action :authenticate_user!, except: [:show, :deezer_search]
  before_action :set_post, only: [:show, :edit, :update, :vote, :destroy]

  def show
    # @post est défini par set_post
  end

  def new
    if Post.exists?(user: current_user, created_at: Time.zone.today.all_day)
      redirect_to root_path, alert: "Vous avez déjà publié un morceau aujourd'hui."
      return
    end
    @post = current_user.posts.build
  end

  def create
    # Vérification de la limite d'un post par jour
    if Post.exists?(user: current_user, created_at: Time.zone.today.all_day)
      redirect_to root_path, alert: "Vous avez déjà publié un morceau aujourd'hui."
      return
    end

    deezer_track_id_param = params.dig(:post, :track_id)
    Rails.logger.debug "--- Post Create Action ---"
    Rails.logger.debug "Received Deezer Track ID param: #{deezer_track_id_param.inspect}"

    if deezer_track_id_param.blank?
      flash.now[:alert] = "Veuillez rechercher et sélectionner un morceau avant de poster."
      @post = current_user.posts.build(description: params.dig(:post, :description))
      render :new, status: :unprocessable_entity and return
    end

    # Logique pour trouver ou créer le Track (associé à current_user pour la "découverte")
    @track = Track.find_or_initialize_by(deezer_track_id: deezer_track_id_param)
    Rails.logger.debug "Track found or initialized: #{@track.persisted? ? "Persisted (ID: #{@track.id})" : 'New Record'}"

    unless @track.persisted?
      Rails.logger.debug "Track not persisted. Fetching details from Deezer for ID: #{deezer_track_id_param}"
      track_data = fetch_deezer_track(deezer_track_id_param)

      unless track_data
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
        user_id: current_user.id # Le track est "découvert" par cet utilisateur
      )
      unless @track.save
        flash.now[:alert] = "Erreur lors de la sauvegarde des infos du morceau : #{@track.errors.full_messages.join(', ')}"
        @post = current_user.posts.build(description: params.dig(:post, :description))
        render :new, status: :unprocessable_entity and return
      end
      Rails.logger.debug "New track saved with ID: #{@track.id}"
    end

    # Création du Post utilisateur
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

    if new_track_id.present? && new_track_id.to_s != @post.track.deezer_track_id.to_s
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
          user_id: current_user.id # Le nouveau track est aussi "découvert" par l'utilisateur actuel
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

  def vote
    # @post est déjà défini par set_post. Cette action s'applique aux Posts de l'application.
    vote_type_param = params[:vote_type]
    unless current_user
      redirect_to new_user_session_path, alert: "Vous devez être connecté pour voter."
      return
    end

    if vote_type_param.blank?
      redirect_back fallback_location: root_path, alert: "Type de vote manquant."
      return
    end

    is_hot_vote = vote_type_param == 'hot'
    existing_vote = @post.votes.find_by(user: current_user)

    if existing_vote
      if existing_vote.vote_type == is_hot_vote
        existing_vote.destroy
        flash[:notice] = "Vote annulé."
      else
        existing_vote.update(vote_type: is_hot_vote)
        flash[:notice] = "Vote mis à jour."
      end
    else
      new_vote = @post.votes.build(user: current_user, vote_type: is_hot_vote)
      if new_vote.save
        flash[:notice] = "Vote enregistré !"
      else
        flash[:alert] = "Impossible d'enregistrer le vote : #{new_vote.errors.full_messages.join(', ')}"
      end
    end
    redirect_back fallback_location: root_path
  end

  # --- MODIFICATION DE create_post_from_deezer_and_vote ---
  def create_post_from_deezer_and_vote
    deezer_track_id = params[:id]
    vote_type_param = params[:vote_type] # 'hot' ou 'cold'

    unless current_user
      redirect_to new_user_session_path, alert: "Vous devez être connecté pour effectuer cette action."
      return
    end

    if deezer_track_id.blank? || vote_type_param.blank?
      redirect_back fallback_location: root_path, alert: "Informations manquantes pour traiter votre demande."
      return
    end

    Rails.logger.info "Interaction utilisateur (vote: #{vote_type_param}) sur suggestion Deezer ID: #{deezer_track_id} par user #{current_user.id}."

    # 1. S'assurer que le Track existe dans notre base (sans nécessairement créer un Post utilisateur)
    track = Track.find_or_initialize_by(deezer_track_id: deezer_track_id)
    unless track.persisted?
      track_data = fetch_deezer_track(deezer_track_id)
      unless track_data
        redirect_back fallback_location: root_path, alert: "Impossible de récupérer les informations du morceau suggéré depuis Deezer."
        return
      end
      track.assign_attributes(
        title: track_data["title_short"] || track_data["title"],
        artist_name: track_data["artist"]["name"],
        album_name: track_data["album"]["title"],
        preview_url: track_data["preview"],
        cover_url: track_data["album"]["cover_medium"],
        link_deezer: track_data["link"],
        duration: track_data["duration"],
        # Qui est le 'user' d'un track qui n'est pas encore un post?
        # Pourrait être le premier utilisateur à interagir, ou nil si la colonne user_id sur tracks le permet.
        # D'après votre schema, tracks.user_id est null: false. Donc, on doit l'assigner.
        # Si on l'assigne à current_user, cela signifie que current_user "possède" la connaissance de ce track dans votre DB.
        user_id: current_user.id
      )
      unless track.save
        redirect_back fallback_location: root_path, alert: "Erreur technique lors de la sauvegarde du morceau suggéré : #{track.errors.full_messages.join(', ')}"
        return
      end
    end

    # IMPORTANT : Nous NE CRÉONS PAS de Post ici.
    # Si vous voulez enregistrer ce "vote" sur la suggestion, il faut une autre logique/table.
    # Par exemple, créer un enregistrement dans une table "SuggestionVotes".
    # Pour l'instant, on affiche juste un message.

    flash[:info] = "Merci ! Votre intérêt pour '#{track.title}' a été noté."
    redirect_back fallback_location: root_path
  end
  # --- FIN DE LA MODIFICATION ---

  def destroy
    if @post.user != current_user
      redirect_back(fallback_location: root_path, alert: "Accès refusé") and return
    end

    @post.destroy
    redirect_back(fallback_location: root_path, notice: "Post supprimé avec succès.")
  end


  def deezer_search
    query = params[:q]
    if query.blank?
      render json: { error: "La requête de recherche est vide." }, status: :bad_request and return
    end

    Rails.logger.debug "Deezer search for query: #{query}"
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
      render json: results
    else
      Rails.logger.error "Deezer search failed: Code=#{response.code}, Message=#{response.message}"
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
      Rails.logger.error "fetch_deezer_track appelé avec un track_id vide."
      return nil
    end
    Rails.logger.debug "Fetching Deezer track details for ID: #{track_id}"
    response = HTTParty.get("https://api.deezer.com/track/#{track_id}")

    if response.success?
      parsed = response.parsed_response
      if parsed.is_a?(Hash) && parsed["id"]
        Rails.logger.debug "Deezer track API success for ID #{track_id}. Data (extrait): id=#{parsed['id']}, title=#{parsed['title_short'] || parsed['title']}"
        if parsed["error"]
          Rails.logger.warn "Deezer API returned an error in a successful response for track ID #{track_id}: #{parsed['error']}"
          return nil
        end
        return parsed
      else
        Rails.logger.error "Réponse Deezer inattendue pour track #{track_id}: #{parsed.inspect}"
      end
    else
      Rails.logger.error "Deezer API Error (HTTParty) for track #{track_id}: Code=#{response.code}, Message=#{response.message}"
    end
    nil
  end
end
