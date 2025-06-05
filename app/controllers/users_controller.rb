class UsersController < ApplicationController
  before_action :authenticate_user!, except: [:show]

  def show
    @user = User.find(params[:id])

    # Initialisation des variables
    @user_posts = @user.posts.order(created_at: :desc)
    @user_playlists = @user.playlists.order(created_at: :desc)

    # Gestion des tracks likées
    @like_playlist = @user.playlists.find_by(name: "Like")  # (sans 's' à "Like")
    @user_tracks = @like_playlist ? @like_playlist.tracks.order(created_at: :desc) : []

    # Variables pour les interactions
    @is_current_user = current_user == @user
    @is_following = user_signed_in? && !@is_current_user ? current_user.following.include?(@user) : false
  end

  def follow
    @user = User.find(params[:id])
    current_user.following << @user
    redirect_to user_path(@user), notice: "Vous suivez maintenant #{@user.username}"
  end

  def unfollow
    @user = User.find(params[:id])
    current_user.following.delete(@user)
    redirect_to user_path(@user), notice: "Vous ne suivez plus #{@user.username}"
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

  def activity
    @user = User.find(params[:id])

    # Activités de follow (abonnements)
    follower_activities = @user.followers.map do |follower|
      follow_record = follower.active_follows.find_by(second_user_id: @user.id)
      {
        type: :follow,
        user: follower,
        created_at: follow_record&.created_at || Time.zone.now
      }
    end

    # Activités de like (votes sur les posts)
    like_activities = Vote.where(post_id: @user.posts.ids).includes(:user, :post).map do |vote|
      {
        type: :like,
        user: vote.user,
        post: vote.post,
        created_at: vote.created_at
      }
    end

    # Fusion, tri descendant par date
    @activity_feed = (follower_activities + like_activities).sort_by { |a| -a[:created_at].to_i }
  end
end
