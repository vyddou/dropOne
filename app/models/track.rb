class Track < ApplicationRecord
  belongs_to :user

  has_many :posts, dependent: :restrict_with_error # Empêche la suppression si des posts y sont liés
  has_many :playlist_items, dependent: :destroy
  has_many :playlists, through: :playlist_items

  has_many :track_genres, dependent: :destroy
  has_many :genres, through: :track_genres

  validates :title, presence: true
  validates :artist_name, presence: true
  validates :deezer_track_id, uniqueness: true, allow_nil: true
end
