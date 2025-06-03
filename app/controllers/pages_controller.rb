class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  def home
    if current_user
      @last_post = current_user.posts.includes(:track)
                        .where("created_at >= ?", Time.zone.now.beginning_of_day)
                        .order(created_at: :desc)
                        .first
    end
  end
end
