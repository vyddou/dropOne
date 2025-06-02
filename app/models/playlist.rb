class Playlist < ApplicationRecord
  belongs_to :user

  has_many :playlist_items, dependent: :destroy
  has_many :tracks, through: :playlist_items

  validates :name, presence: true
