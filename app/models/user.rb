class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :tracks, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_many :playlist_items, through: :playlists
  has_many :votes, dependent: :destroy
  has_many :messages, dependent: :destroy

  has_many :conversation_participants, dependent: :destroy
  has_many :conversations, through: :conversation_participants

  # Système de "follow"
  # L'utilisateur "suit" d'autres utilisateurs (active)
  # La clé étrangère dans la table 'follows' pour celui qui suit est 'first_user_id'
  has_many :active_follows, class_name: 'Follow', foreign_key: 'first_user_id', dependent: :destroy
  # À travers 'active_follows', on trouve les utilisateurs suivis (qui sont les 'second_user' dans la table 'follows')
  has_many :following, through: :active_follows, source: :second_user

  # L'utilisateur "est suivi par" d'autres utilisateurs (passive)
  # La clé étrangère dans la table 'follows' pour celui qui est suivi est 'second_user_id'
  has_many :passive_follows, class_name: 'Follow', foreign_key: 'second_user_id', dependent: :destroy
  # À travers 'passive_follows', on trouve les utilisateurs qui suivent (qui sont les 'first_user' dans la table 'follows')
  has_many :followers, through: :passive_follows, source: :first_user

  validates :username, uniqueness: true

  validates :description, length: { maximum: 500 }

  def follows?(user)
    following.include?(user)
  end

  def unread_messages_count
    Message.joins(:conversation)
           .where(conversations: { id: self.conversations.ids })
           .where.not(user_id: self.id)
           .unread
           .count
  end

  def liked?(post_id)
    vote = votes.find_by(post_id: post_id)
    puts "Vote pour post_id #{post_id}: #{vote.inspect}"
    vote&.vote_type
  end

  def has_new_activities?(last_check = nil)
    # Si pas de dernière vérification, on considère qu'il y a des nouvelles activités
    return true if last_check.nil?
    
    # Vérifier s'il y a de nouveaux follows depuis la dernière vérification
    new_follows = followers.joins(:active_follows)
                          .where('follows.created_at > ?', last_check)
                          .exists?
    
    # Vérifier s'il y a de nouveaux likes depuis la dernière vérification
    new_likes = Vote.where(post_id: posts.ids)
                   .where('created_at > ?', last_check)
                   .exists?
    
    new_follows || new_likes
  end

      def vote_for(post)
    votes.find_by(post_id: post.id)
  end

end
