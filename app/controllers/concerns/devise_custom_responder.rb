module DeviseCustomResponder
  protected

  def after_sign_in_path_for(resource)
    flash[:notice] = I18n.t('devise.sessions.signed_in', username: resource.username) # ou .pseudo, .first_name, etc.
    super
  end
end