class Follow < ApplicationRecord
  belongs_to :first_user,class_name: 'User' # Rails déduira foreign_key: 'first_user_id'
  belongs_to :second_user, class_name: 'User'

  validates :first_user_id, presence: true
  validates :second_user_id, presence: true
  validates :first_user_id, uniqueness: { scope: :second_user_id, message: "already following this user" }

  validate :cannot_follow_self

  def cannot_follow_self
    errors.add(:base, "You cannot follow yourself") if first_user_id == second_user_id
  end
end
