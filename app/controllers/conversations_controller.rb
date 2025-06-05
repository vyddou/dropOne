class ConversationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @conversations = current_user.conversations
  end

  def show
    @conversation = Conversation.find(params[:id])
    unless @conversation.users.include?(current_user)
      redirect_to conversations_path, alert: "Non autorisé."
      return
    end
    @messages = @conversation.messages.order(created_at: :asc)
    @message = Message.new
    @messages.where.not(user_id: current_user.id).where(read_at: nil).update_all(read_at: Time.current)
  end

  def create
    other_user = User.find(params[:user_id])

    conversation = Conversation.joins(:conversation_participants)
      .where(conversation_participants: { user_id: [current_user.id, other_user.id] })
      .group('conversations.id')
      .having('COUNT(*) = 2')
      .first

    unless conversation
      conversation = Conversation.create!
      conversation.users << current_user
      conversation.users << other_user
    end

    redirect_to conversation_path(conversation)
  end

  def destroy
    @conversation = Conversation.find(params[:id])

    # Optionnel : vérifier que current_user est bien participant pour sécuriser
    if @conversation.users.include?(current_user)
      @conversation.destroy
      redirect_to conversations_path, notice: "Conversation supprimée avec succès."
    else
      redirect_to conversations_path, alert: "Vous ne pouvez pas supprimer cette conversation."
    end
  end
end
