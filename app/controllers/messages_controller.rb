class MessagesController < ApplicationController
  before_action :authenticate_user!

  def create
    @conversation = Conversation.find(params[:conversation_id])
    @message = @conversation.messages.build(message_params)
    @message.user = current_user

    if @message.save
      redirect_to conversation_path(@conversation)
    else
      flash[:alert] = "Impossible d'envoyer le message."
      render 'conversations/show', status: :unprocessable_entity
    end
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
