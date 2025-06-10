class MessagesController < ApplicationController
  before_action :authenticate_user!

  def create
    @conversation = Conversation.find(params[:conversation_id])
    @message = @conversation.messages.build(message_params)
    @message.user = current_user
    @messages = @conversation.messages.order(:created_at)

    if @message.save
      # Notifier tous les autres participants de la conversation
      @conversation.conversation_participants.includes(:user).each do |participant|
        if participant.user != current_user
          NotificationService.notify_new_message(participant.user, current_user, @message)
        end
      end
      
      redirect_to conversation_path(@conversation)
    else
      flash.now[:alert] = "Impossible d'envoyer le message car il est vide."
      render 'conversations/show', status: :unprocessable_entity
    end
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
