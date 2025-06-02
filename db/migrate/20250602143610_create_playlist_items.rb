class CreatePlaylistItems < ActiveRecord::Migration[7.1]
  def change
    create_table :playlist_items do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true
      t.integer :order_in_playlist

      t.timestamps
    end
  end
end
