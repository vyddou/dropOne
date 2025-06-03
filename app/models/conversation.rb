# app/models/conversation.rb
class Conversation < ApplicationRecord
  has_many :conversation_participants, dependent: :destroy
  # Important: `uniq: true` ici assure que `conversation.users` ne renverra que des utilisateurs uniques,
  # même si, par erreur, plusieurs enregistrements ConversationParticipant pointeraient vers le même user pour cette conversation.
  has_many :users, -> { distinct }, through: :conversation_participants
  has_many :messages, dependent: :destroy

  # Validation: Si des participants sont associés à la conversation,
  # il doit y en avoir au moins deux distincts.
  validate :must_have_at_least_two_distinct_participants

  # Méthode de classe pour trouver ou créer une conversation directe (DM) entre deux utilisateurs.
  def self.find_or_create_dm(user1, user2)
    raise ArgumentError, "Les utilisateurs doivent être fournis et valides." if user1.nil? || user2.nil? || !user1.is_a?(User) || !user2.is_a?(User)
    raise ArgumentError, "Les utilisateurs doivent être distincts pour créer un DM." if user1.id == user2.id

    # Cherche une conversation existante qui est un DM entre ces deux utilisateurs.
    # Un DM est défini comme une conversation ayant exactement ces deux utilisateurs comme participants.
    # Note: `user1.conversations` récupère toutes les conversations (y compris de groupe) où user1 est présent.
    # Nous filtrons ensuite pour trouver celle qui est un DM avec user2.
    dm_conversation = user1.conversations.includes(:users).find do |convo|
      # Vérifie si la conversation a exactement 2 participants
      # et si ces participants sont bien user1 et user2.
      participant_ids = convo.user_ids # Ceci vient de `has_many :users`
      participant_ids.length == 2 && participant_ids.sort == [user1.id, user2.id].sort
    end

    return dm_conversation if dm_conversation

    # Si aucune conversation DM existante n'est trouvée, en créer une nouvelle.
    # Utilise une transaction pour s'assurer que la conversation et les participations
    # sont créées de manière atomique.
    transaction do
      new_conversation = Conversation.new
      # Ajoute les utilisateurs à la conversation. Cela créera implicitement
      # les enregistrements ConversationParticipant nécessaires.
      new_conversation.users << user1
      new_conversation.users << user2

      # `save!` lèvera une exception si la validation (y compris la nôtre) échoue.
      new_conversation.save!
      new_conversation # Retourne la conversation nouvellement créée
    end
  end

  private

  def must_have_at_least_two_distinct_participants
    # Cette validation s'exécute lors de la sauvegarde (création/mise à jour).
    # Elle vérifie l'état actuel de l'association `users`.
    # `self.users` reflète les utilisateurs associés via `conversation_participants`
    # qui ne sont pas marqués pour destruction. `-> { distinct }` dans la définition de `has_many :users`
    # garantit que `self.users.size` compte les utilisateurs uniques.

    # Si la conversation a des participants (c'est-à-dire que la collection
    # `conversation_participants` n'est pas vide après avoir retiré ceux marqués pour destruction),
    # alors il doit y avoir au moins deux utilisateurs uniques.
    if self.conversation_participants.reject(&:marked_for_destruction?).any? && self.users.size < 2
      errors.add(:base, "Une conversation doit avoir au moins deux participants distincts.")
    end
    # Cette logique permet de créer une Conversation vide (`Conversation.new.save`) sans erreur,
    # mais si on tente d'y associer des participants, il en faudra au moins deux.
    # Notre méthode `find_or_create_dm` ajoute toujours deux participants avant `save!`,
    # donc elle passera cette validation.
  end
end
