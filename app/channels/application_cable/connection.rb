module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Utilise la session Devise existante
      if session_user_id = request.session['warden.user.user.key']&.first&.first
        User.find_by(id: session_user_id)
      else
        reject_unauthorized_connection
      end
    end
  end
end
