class ChangeDeezerTrackIdToBigintInTracks < ActiveRecord::Migration[7.1]
  def change
    change_column :tracks, :deezer_track_id, :bigint
  end
end
