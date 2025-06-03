class ApplicationController < ActionController::Base
  before_action :authenticate_user! # Assurez-vous que cela existe si vous voulez une authentification par défaut
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    # Pour l'inscription (sign_up)
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :first_name, :last_name])

    # Pour la mise à jour du compte (account_update)
    devise_parameter_sanitizer.permit(:account_update, keys: [:username, :first_name, :last_name, :avatar_url, :bio]) # Ajoutez d'autres attributs que l'utilisateur peut modifier
  end
end
