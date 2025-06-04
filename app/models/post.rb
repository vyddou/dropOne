class Post < ApplicationRecord
  belongs_to :user
  belongs_to :track

  has_many :comments, dependent: :destroy
  has_many :votes, dependent: :destroy

  validates :description, length: { maximum: 1000 }

  # Ajoutez cette méthode pour le formatage de date
  def posted_at
    created_at.strftime("%d/%m/%Y à %H:%M")
  end

  # app/models/post.rb
  def formatted_date
    today = Time.zone.now.to_date
    
    case created_at.to_date
    when today
      "Post du jour"
    when today - 1.day
      "Posté hier"
    when today - 2.days..today - 1.day
      "Posté #{I18n.l(created_at, format: '%A')}"
    when today.beginning_of_year..today
      # Même année
      "Posté le #{I18n.l(created_at, format: '%d %B')}"
    else
      # Année différente
      "Posté le #{I18n.l(created_at, format: '%d %B %Y')}"
    end
  end
end
