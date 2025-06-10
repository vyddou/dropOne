class ApplicationController < ActionController::Base
  before_action :authenticate_user! # Assurez-vous que cela existe si vous voulez une authentification par défaut
  before_action :configure_permitted_parameters, if: :devise_controller?

  def after_sign_in_path_for(resource)
    flash[:notice] = "Bon retour parmi nous #{resource.username} ! 🎵" if resource.respond_to?(:username)
    super
  end

  protected

  def configure_permitted_parameters
 
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :first_name, :last_name])

    devise_parameter_sanitizer.permit(:account_update, keys: [:username, :first_name, :last_name, :avatar_url, :description]) # Ajoutez d'autres attributs que l'utilisateur peut modifier
  end
end
