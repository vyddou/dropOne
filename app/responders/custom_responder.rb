# app/responders/custom_responder.rb

class CustomResponder < ActionController::Responder
  # Incluez les modules de la gem 'responders' pour garder les fonctionnalités de base.
  include Responders::FlashResponder
  include Responders::HttpHeaderResponder

  # C'est ici que vous pouvez ajouter votre logique personnalisée si vous en avez.
  # Par exemple, pour changer le comportement des redirections après une action.
end
