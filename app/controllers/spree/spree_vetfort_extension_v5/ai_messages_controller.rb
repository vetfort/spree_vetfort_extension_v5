module Spree
  module SpreeVetfortExtensionV5
    class AiMessagesController < Spree::StoreController
      before_action :find_conversation

      def create
        @message = ai_message_params[:content]

        @conversation.append_message(role: 'user', content: @message)

        AiChatJob.perform_later(@conversation.id)
      end

      private

      def ai_message_params
        params.permit(:content, :ai_conversation_id)
      end

      def find_conversation
        @conversation = Spree::VetfortExtensionV5::AiConsultantConversation.find(ai_message_params[:ai_conversation_id])
      end
    end
  end
end
