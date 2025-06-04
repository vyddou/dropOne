class UsersController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  def show
    @user = User.find(params[:id])
    @is_current_user = current_user == @user
    @is_following = current_user.following.include?(@user) if user_signed_in? && !@is_current_user
  end

  def follow
    @user = User.find(params[:id])
    current_user.following << @user
    redirect_to user_path(@user), notice: "Vous suivez maintenant #{@user.email}"
  end

  def unfollow
    @user = User.find(params[:id])
    current_user.following.delete(@user)
    redirect_to user_path(@user), notice: "Vous ne suivez plus #{@user.email}"
  end
end
