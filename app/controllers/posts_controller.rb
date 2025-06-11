# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  # Le before_action pour :authenticate_user! est bon.
  # On retire :vote de set_post car cette action n'est plus ici.
  before_action :authenticate_user!, except: [:show, :deezer_search]
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  before_action :check_daily_post_limit!, only: [:new, :create]
  before_action :authorize_user!, only: [:edit, :update, :destroy]

  def show
    # @post est déjà défini par le before_action :set_post
    @comments = @post.comments.includes(:user)
  end

  def new
    @post = current_user.posts.build
  end

  def create
    track = find_or_create_track(params.dig(:post, :track_id))

    # Si la recherche du morceau a échoué, on arrête
    unless track
      flash.now[:alert] = "Impossible de trouver les informations pour ce morceau."
      @post = current_user.posts.build(post_params) # Re-construit l'objet avec les params pour le form
      render :new, status: :unprocessable_entity and return
    end

    @post = current_user.posts.build(post_params.merge(track: track))

    if @post.save
      redirect_to root_path, notice: "Post créé avec succès !"
    else
      flash.now[:alert] = "Erreur lors de la création du post : #{@post.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # L'autorisation est gérée par authorize_user!
  end

  def update
    track = if params.dig(:post, :track_id).present? && params.dig(:post, :track_id) != @post.track.deezer_track_id.to_s
              find_or_create_track(params.dig(:post, :track_id))
            else
              @post.track
            end

    unless track
      flash.now[:alert] = "Impossible de trouver les informations pour le nouveau morceau."
      render :edit, status: :unprocessable_entity and return
    end

    if @post.update(post_params.merge(track: track))
      redirect_to root_path, notice: "Post mis à jour avec succès !"
    else
      flash.now[:alert] = "Erreur lors de la mise à jour du post : #{@post.errors.full_messages.join(', ')}"
      render :edit, status: :unprocessable_entity
    end
  end

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
      return render json: { error: "La requête de recherche est vide." }, status: :bad_request
    end

    response = HTTParty.get("https://api.deezer.com/search", query: { q: query, limit: 10 })
    if response.success? && response.parsed_response&.dig("data")
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
      render json: { error: "La recherche Deezer a échoué." }, status: :service_unavailable
    end
  rescue StandardError => e
    render json: { error: "Erreur interne du serveur." }, status: :internal_server_error
  end

  private

  def set_post
    @post = Post.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Post non trouvé."
  end

  # Méthode pour centraliser la logique de recherche/création de Track
  def find_or_create_track(deezer_track_id)
    return nil if deezer_track_id.blank?

    track = Track.find_or_initialize_by(deezer_track_id: deezer_track_id)
    return track if track.persisted?

    track_data = fetch_deezer_track(deezer_track_id)
    return nil unless track_data

    track.assign_attributes(
      title: track_data["title_short"] || track_data["title"],
      artist_name: track_data["artist"]["name"],
      album_name: track_data["album"]["title"],
      preview_url: track_data["preview"],
      cover_url: track_data["album"]["cover_medium"],
      link_deezer: track_data["link"],
      duration: track_data["duration"],
      user_id: current_user.id # Le track est "découvert" par cet utilisateur
    )

    track.save ? track : nil
  end

  def fetch_deezer_track(track_id)
    return nil if track_id.blank?
    response = HTTParty.get("https://api.deezer.com/track/#{track_id}")
    return nil unless response.success?
    parsed = response.parsed_response
    parsed if parsed.is_a?(Hash) && parsed["id"] && !parsed["error"]
  end

  def post_params
    params.require(:post).permit(:description)
  end

  def check_daily_post_limit!
    if Post.exists?(user: current_user, created_at: Time.zone.today.all_day)
      redirect_to root_path, alert: "Vous avez déjà publié un morceau aujourd'hui."
    end
  end

  def authorize_user!
    redirect_to root_path, alert: "Accès refusé." unless @post.user == current_user
  end
end
