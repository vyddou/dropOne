class Playlist < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :playlist_items, dependent: :destroy
  # has_many :songmarks, dependent: :destroy  # ancienne version IA
  has_many :tracks, through: :songmarks
  has_many :tracks, through: :playlist_items

  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, message: "Cet intitulé existe déja parmis vos playlists" }

  # Constantes pour les noms des playlists
  LIKE_PLAYLIST_NAME = "Like"
  DISLIKE_PLAYLIST_NAME = "Dislikes"

  # Méthode pour ajouter un morceau
  def add_track(track)
    tracks << track unless tracks.include?(track)
  end
end
