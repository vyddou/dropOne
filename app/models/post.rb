class Post < ApplicationRecord
  belongs_to :user
  belongs_to :track

  has_many :comments, dependent: :destroy
  has_many :votes, dependent: :destroy

  validates :description, length: { maximum: 1000 }
end
