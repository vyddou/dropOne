class PlaylistItem < ApplicationRecord
  belongs_to :playlist
  belongs_to :track

  validates :order_in_playlist, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :track_id, uniqueness: { scope: :playlist_id, message: "est déjà dans cette playlist." }
end
