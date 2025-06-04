class UsersController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  def show
    @user = User.find(params[:id])
    
    # Initialisation des variables
    @user_posts = @user.posts.order(created_at: :desc)
    @user_playlists = @user.playlists.order(created_at: :desc)
    
    # Gestion des tracks likées
    @like_playlist = @user.playlists.find_by(name: "Like") ######## s ou pas ??
    @user_tracks = @like_playlist ? @like_playlist.tracks.order(created_at: :desc) : []
    
    # Variables pour les interactions
    @is_current_user = current_user == @user
    @is_following = current_user.following.include?(@user) if user_signed_in? && !@is_current_user
  end

  def follow
    @user = User.find(params[:id])
    current_user.following << @user
    redirect_to user_path(@user), notice: "Vous suivez maintenant #{@user.email}"
  end

  def unfollow
    @user = User.find(params[:id])
    current_user.following.delete(@user)
    redirect_to user_path(@user), notice: "Vous ne suivez plus #{@user.email}"
  end

  def update_description
    if current_user == User.find(params[:id])
      if current_user.update(description: params[:user][:description])
        redirect_to user_path(current_user), notice: "Description mise à jour."
      else
        redirect_to user_path(current_user), alert: "Erreur lors de la mise à jour."
      end
    else
      redirect_to root_path, alert: "Non autorisé."
    end
  end

end
