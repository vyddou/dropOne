class AddDescriptionToPlaylistItems < ActiveRecord::Migration[7.1]
  def change
    add_column :playlist_items, :description, :text
  end
end
