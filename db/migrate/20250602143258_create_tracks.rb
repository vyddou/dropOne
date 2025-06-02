class CreateTracks < ActiveRecord::Migration[7.1]
  def change
    create_table :tracks do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :deezer_track_id
      t.string :title
      t.string :artist_name
      t.string :album_name
      t.integer :duration
      t.string :preview_url
      t.string :cover_url
      t.string :link_deezer

      t.timestamps
    end
  end
end
