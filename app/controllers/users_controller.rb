class UsersController < ApplicationController
  before_action :authenticate_user!, except: [:show]

  def show

  @user = User.find(params[:id])

  # Initialisation des variables
  @user_posts = @user.posts.order(created_at: :desc)

  @user_playlists = @user.playlists.order(created_at: :desc)
                      .reject { |playlist| ["Like", "Dislikes"].include?(playlist.name) }

  # 1. Posts likés via les votes
  posts_from_votes = Post.joins(:votes)
                         .where(votes: { user_id: @user.id, vote_type: true })
                         .includes(:track, :user, :votes, :comments)

  # On commence avec les posts votés
  liked_content = posts_from_votes.to_a

  # 2. Tracks depuis la playlist "Like"
  like_playlist = @user.playlists.find_by(name: "Like")

  if like_playlist
    # IDs des tracks déjà inclus via les votes
    existing_track_ids = liked_content.map(&:track_id)

    # On charge les items de la playlist pour avoir la date d'ajout, et on précharge les tracks
    playlist_items = like_playlist.playlist_items.includes(track: [:user, :posts]).order(created_at: :desc)

    playlist_items.each do |item|
      track = item.track
      # On ajoute seulement si un post pour cette track n'est pas déjà dans la liste
      unless existing_track_ids.include?(track.id)
        # On cherche un post existant pour cette track (le plus ancien, par exemple)
        existing_post = track.posts.order(created_at: :asc).first

        if existing_post
          # Si un post existe, on l'ajoute (s'il n'y est pas déjà par son id)
          liked_content << existing_post unless liked_content.any? { |p| p.id == existing_post.id }
        else
          # Si aucun post n'existe, on crée un objet Post en mémoire (non sauvegardé)
          dummy_post = Post.new(
            track: track,
            user: track.user, # Le post est attribué à l'auteur original de la track
            created_at: item.created_at # On utilise la date d'ajout à la playlist pour le tri
          )
          liked_content << dummy_post
        end
      end
    end
  end

  # 3. Dédoublonner par track et trier
  @liked_posts = liked_content.uniq { |p| p.track_id }.sort_by(&:created_at).reverse


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
