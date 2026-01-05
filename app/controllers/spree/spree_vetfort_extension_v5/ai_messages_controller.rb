module Spree
  module SpreeVetfortExtensionV5
    class AiMessagesController < Spree::StoreController
      before_action :find_conversation

      def create
        @message = ai_message_params[:content]

        append_context_message(@conversation)
        @conversation.append_message(role: 'user', content: @message)

        AiChatJob.perform_later(@conversation.id)

        respond_to do |format|
          format.turbo_stream { render turbo_stream: [], status: :accepted }
          format.json { render json: { ok: true }, status: :accepted }
          format.any { head :accepted }
        end
      end

      private

      def ai_message_params
        params.permit(:content, :ai_conversation_id, :path)
      end

      def find_conversation
        @conversation = Spree::VetfortExtensionV5::AiConsultantConversation.find(ai_message_params[:ai_conversation_id])
      end

      def append_context_message(conversation)
        context = ContextResolver.new(ai_message_params[:path]).call
        return if context.blank?

        conversation.append_message(role: 'system', content: context)
      end

    end
  end
end
