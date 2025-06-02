class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :user # L'expéditeur du message

  validates :content, presence: true

  # Pour que les messages s'affichent dans l'ordre
  default_scope { order(created_at: :asc) }
end
