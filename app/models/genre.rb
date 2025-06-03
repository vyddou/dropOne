class Genre < ApplicationRecord
  has_many :track_genres, dependent: :destroy
  has_many :tracks, through: :track_genres

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
