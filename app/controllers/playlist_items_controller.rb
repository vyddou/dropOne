class PlaylistItemsController < ApplicationController

  before_action :authenticate_user!

  LIKE_PLAYLIST_NAME = Playlist::LIKE_PLAYLIST_NAME
  DISLIKE_PLAYLIST_NAME = Playlist::DISLIKE_PLAYLIST_NAME

  def like
    playlist_item = current_user.playlist_items.find(params[:id])
    liked_playlist = current_user.playlists.find_or_create_by(name: LIKE_PLAYLIST_NAME)

    result = handle_playlist_item_action(playlist_item, liked_playlist, "likée", "dislikée")
    redirect_to playlist_item.playlist, result
  end

  def dislike
    playlist_item = current_user.playlist_items.find(params[:id])
    disliked_playlist = current_user.playlists.find_or_create_by(name: DISLIKE_PLAYLIST_NAME)

    result = handle_playlist_item_action(playlist_item, disliked_playlist, "dislikée", "likée")
    redirect_to playlist_item.playlist, result
  end

  def remove_from_likes
    @playlist_item = current_user.playlist_items.find(params[:id])
    @playlist_item.destroy
    
    respond_to do |format|
      format.html { redirect_to user_path(current_user), notice: "Musique retirée des likes" }
      format.turbo_stream  # Optionnel si vous utilisez Hotwire
    end
  end
  
  def dislike_all_songs
    playlist = Playlist.find(params[:playlist_id])
    disliked_playlist = current_user.playlists.find_or_create_by(name: DISLIKE_PLAYLIST_NAME)

    results = { success: 0, already_liked: 0, already_disliked: 0 }

    playlist.playlist_items.each do |playlist_item|
      result = handle_playlist_item_action(playlist_item, disliked_playlist, "dislikée", "likée", true)
      results[result[:type]] += 1
    end

    notice_message = "Résultat : #{results[:success]} chanson(s) likée(s), #{results[:already_liked]} déjà likée(s), #{results[:already_disliked]} déjà dislikée(s)."
    redirect_to playlist, notice: notice_message
  end

  def like_all_songs
    playlist = Playlist.find(params[:playlist_id])
    liked_playlist = current_user.playlists.find_or_create_by(name: LIKE_PLAYLIST_NAME)

    results = { success: 0, already_liked: 0, already_disliked: 0 }

    playlist.playlist_items.each do |playlist_item|
      result = handle_playlist_item_action(playlist_item, liked_playlist, "likée", "dislikée", true)
      results[result[:type]] += 1
    end

    notice_message = "Résultat : #{results[:success]} chanson(s) likée(s), #{results[:already_liked]} déjà likée(s), #{results[:already_disliked]} déjà dislikée(s)."
    redirect_to playlist, notice: notice_message
  end

  def destroy
    playlist_item = current_user.playlist_items.find(params[:id])
    playlist_item.destroy
    redirect_to playlist_item.playlist, notice: 'Chanson supprimée avec succès.'
  end
  
  private

  def handle_playlist_item_action(playlist_item, target_playlist, target_action, opposite_action, batch_mode = false)
    existing_playlist_item = current_user.playlist_items.find_by(playlist: target_playlist, track: playlist_item.track)


    if existing_playlist_item
      return { type: :already_liked, notice: "Cette chanson est déjà #{target_action}." } unless batch_mode
      return { type: :already_liked }
    else
      opposite_playlist = current_user.playlists.find_by(name: opposite_action == "likée" ? LIKE_PLAYLIST_NAME : DISLIKE_PLAYLIST_NAME)
      opposite_playlist_item = current_user.playlist_items.find_by(playlist: opposite_playlist, track: playlist_item.track) if opposite_playlist

      if opposite_playlist_item
        return { type: :already_disliked, notice: "Impossible de #{target_action} cette chanson car elle est déjà #{opposite_action}." } unless batch_mode
        return { type: :already_disliked }
      else
        PlaylistItem.create!(playlist: target_playlist, track: playlist_item.track)
        return { type: :success, notice: "Chanson #{target_action} avec succès." } unless batch_mode
        return { type: :success }
      end
    end
  end
end
