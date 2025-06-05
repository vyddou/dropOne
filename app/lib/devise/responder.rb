module Devise
  class CustomResponder < ::Devise::Responder
    def to_html
      if notice == I18n.t('devise.sessions.signed_in') && resource.respond_to?(:username)
        set_flash_message(:notice, :signed_in, username: resource.username)
      end
      super
    end
  end
end
