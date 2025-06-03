class PostsController < ApplicationController
  before_action :set_post, only: [:edit, :update]

  def new
    @post = Post.new
  end

  def create
    @track = Track.find_or_initialize_by(deezer_track_id: params[:post][:track_id])

    unless @track.persisted?
      track_data = fetch_deezer_track(params[:post][:track_id])

      unless track_data
        redirect_to root_path, alert: "Erreur lors de la récupération des infos Deezer" and return
      end

      @track.assign_attributes(
        title: track_data["title"],
        artist_name: track_data["artist"]["name"],
        album_name: track_data["album"]["title"],
        preview_url: track_data["preview"],
        cover_url: track_data["album"]["cover_medium"],
        link_deezer: track_data["link"],
        duration: track_data["duration"],
        user: current_user
      )
      @track.save
    end

    @post = Post.new(
      user: current_user,
      track: @track,
      description: params[:post][:description]
    )

    if @post.save
      session[:last_post_id] = @post.id
      redirect_to root_path, notice: "Post créé avec succès !"
    else
      render :new
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
    if params[:post][:track_id].present? && params[:post][:track_id] != @post.track.deezer_track_id.to_s
      @track = Track.find_or_initialize_by(deezer_track_id: params[:post][:track_id])

      unless @track.persisted?
        track_data = fetch_deezer_track(params[:post][:track_id])

        unless track_data
          redirect_to edit_post_path(@post), alert: "Erreur lors de la récupération des infos Deezer" and return
        end

        @track.assign_attributes(
          title: track_data["title"],
          artist_name: track_data["artist"]["name"],
          album_name: track_data["album"]["title"],
          preview_url: track_data["preview"],
          cover_url: track_data["album"]["cover_medium"],
          link_deezer: track_data["link"],
          duration: track_data["duration"],
          user: current_user
        )
        @track.save
      end
    else
      @track = @post.track
    end

    if @post.update(track: @track, description: params[:post][:description])
      redirect_to root_path, notice: "Post mis à jour avec succès !"
    else
      render :edit
    end
  end

  def deezer_search
    query = params[:q]
    response = HTTParty.get("https://api.deezer.com/search", query: { q: query })
    results = response.parsed_response["data"].map do |track|
      {
        id: track["id"],
        title: track["title"],
        artist: track["artist"]["name"],
        preview: track["preview"],
        cover: track["album"]["cover_medium"]
      }
    end

    render json: results
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def fetch_deezer_track(track_id)
    response = HTTParty.get("https://api.deezer.com/track/#{track_id}")
    if response.code == 200
      parsed = response.parsed_response
      return parsed unless parsed["error"]
    end
    nil
  end
end
