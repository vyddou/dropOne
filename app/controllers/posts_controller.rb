# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  before_action :authenticate_user!, except: [:show] # Permet de voir un post sans être connecté, optionnel
  before_action :set_post, only: [:show, :edit, :update] # Ajout de :show ici

  def show
    # @post est déjà défini par le before_action :set_post
    # Vous pouvez ajouter ici la logique pour charger les commentaires du post, par exemple :
    # @comments = @post.comments.order(created_at: :desc)
    # @comment = Comment.new # Pour un formulaire de nouveau commentaire sur la page show
  end

  def new
    @post = current_user.posts.build # Assure que le post est initialisé avec l'utilisateur actuel
  end

  def create
    # Votre logique pour trouver ou créer le Track
    @track = Track.find_or_initialize_by(deezer_track_id: params[:post][:track_id])

    unless @track.persisted?
      track_data = fetch_deezer_track(params[:post][:track_id])

      unless track_data
        # Il serait peut-être mieux de rendre :new avec une alerte plutôt que de rediriger vers root
        flash.now[:alert] = "Erreur lors de la récupération des infos Deezer pour le morceau."
        @post = Post.new(description: params[:post][:description]) # Recrée @post pour que le formulaire ne soit pas vide
        render :new, status: :unprocessable_entity and return
      end

      @track.assign_attributes(
        title: track_data["title"],
        artist_name: track_data["artist"]["name"],
        album_name: track_data["album"]["title"],
        preview_url: track_data["preview"],
        cover_url: track_data["album"]["cover_medium"], # ou cover_big
        link_deezer: track_data["link"],
        duration: track_data["duration"],
        user_id: current_user.id # Assurez-vous que user_id est bien défini pour la table tracks si elle a cette colonne
                                 # Si la table tracks n'a pas de user_id, retirez cette ligne.
                                 # D'après votre schema.rb, tracks a un user_id, donc c'est correct.
      )
      unless @track.save
        # Gérer l'échec de la sauvegarde du track
        flash.now[:alert] = "Erreur lors de la sauvegarde des informations du morceau."
        @post = Post.new(description: params[:post][:description])
        render :new, status: :unprocessable_entity and return
      end
    end

    @post = current_user.posts.build( # Utilise build pour associer directement à current_user
      track: @track,
      description: params[:post][:description]
    )

    if @post.save
      # session[:last_post_id] = @post.id # Vous n'utilisez plus @last_post de cette manière
      redirect_to root_path, notice: "Post créé avec succès !"
    else
      # Si la sauvegarde du post échoue, @track est déjà défini.
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Sécurisation : seul le propriétaire peut éditer
    redirect_to root_path, alert: "Accès refusé" unless @post.user == current_user
  end

  def update
    # Sécurisation : seul le propriétaire peut mettre à jour
    unless @post.user == current_user
      redirect_to root_path, alert: "Accès refusé" and return
    end

    # Gestion du changement de musique
    new_track_id = params[:post][:track_id]
    if new_track_id.present? && new_track_id != @post.track.deezer_track_id.to_s
      @new_track = Track.find_or_initialize_by(deezer_track_id: new_track_id)

      unless @new_track.persisted?
        track_data = fetch_deezer_track(new_track_id)

        unless track_data
          flash.now[:alert] = "Erreur lors de la récupération des infos Deezer pour le nouveau morceau."
          render :edit, status: :unprocessable_entity and return
        end

        @new_track.assign_attributes(
          title: track_data["title"],
          artist_name: track_data["artist"]["name"],
          album_name: track_data["album"]["title"],
          preview_url: track_data["preview"],
          cover_url: track_data["album"]["cover_medium"],
          link_deezer: track_data["link"],
          duration: track_data["duration"],
          user_id: current_user.id # ou @post.user_id si le user du track ne doit pas changer
        )
        unless @new_track.save
          flash.now[:alert] = "Erreur lors de la sauvegarde du nouveau morceau."
          render :edit, status: :unprocessable_entity and return
        end
      end
      # Assigner le nouveau track au post
      post_params_for_update = { track: @new_track, description: params[:post][:description] }
    else
      # Pas de changement de track, on met juste à jour la description
      post_params_for_update = { description: params[:post][:description] }
    end

    if @post.update(post_params_for_update)
      redirect_to root_path, notice: "Post mis à jour avec succès !" # Ou redirect_to post_path(@post)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def deezer_search
    query = params[:q]
    response = HTTParty.get("https://api.deezer.com/search", query: { q: query })
    if response.success? && response.parsed_response["data"]
      results = response.parsed_response["data"].map do |track|
        {
          id: track["id"],
          title: track["title_short"] || track["title"],
          artist: track["artist"]["name"],
          preview: track["preview"],
          cover: track["album"]["cover_medium"] # ou cover_small / cover_big
        }
      end
      render json: results
    else
      render json: { error: "Deezer search failed", details: response.message }, status: response.code || 500
    end
  rescue StandardError => e
    render json: { error: "Internal server error", details: e.message }, status: 500
  end

  private

  def set_post
    @post = Post.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Post non trouvé."
  end

  # Pas besoin de post_params pour l'instant car vous accédez directement à params[:post][:description] etc.
  # Mais si vous aviez plus de champs pour Post, ce serait :
  # def post_params
  #   params.require(:post).permit(:description, :track_id) # track_id est géré séparément en fait
  # end

  def fetch_deezer_track(track_id)
    response = HTTParty.get("https://api.deezer.com/track/#{track_id}")
    if response.success?
      parsed = response.parsed_response
      # Vérifie si Deezer retourne une erreur dans le JSON (ex: track non trouvé)
      return parsed unless parsed.is_a?(Hash) && parsed["error"]
    else
      Rails.logger.error "Deezer API Error for track #{track_id}: #{response.code} - #{response.message}"
    end
    nil # Retourne nil si l'appel échoue ou si Deezer retourne une erreur
  end
end
