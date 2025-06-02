class Vote < ApplicationRecord
  belongs_to :user
  belongs_to :post

  validates :vote_type, inclusion: { in: [true, false] }
  validates :user_id, uniqueness: { scope: :post_id, message: "ne peut voter qu'une fois par post." }
end
