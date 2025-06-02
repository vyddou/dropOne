class CreateTrackGenres < ActiveRecord::Migration[7.1]
  def change
    create_table :track_genres do |t|
      t.references :track, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true

      t.timestamps
    end
  end
end
