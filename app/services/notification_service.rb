class NotificationService
  def self.notify_new_follow(followed_user, follower)
    ActionCable.server.broadcast(
      "notifications_#{followed_user.id}",
      {
        type: 'activity',
        message: "#{follower.username} vous suit maintenant"
      }
    )
  end

  def self.notify_new_like(post_owner, liker, post)
    ActionCable.server.broadcast(
      "notifications_#{post_owner.id}",
      {
        type: 'activity',
        message: "#{liker.username} a aimé votre post"
      }
    )
  end

  def self.notify_new_message(recipient, sender, message)
    unread_count = recipient.unread_messages_count
    
    ActionCable.server.broadcast(
      "notifications_#{recipient.id}",
      {
        type: 'message',
        count: unread_count,
        message: "Nouveau message de #{sender.username}"
      }
    )
  end
end