require 'faker'

module Spree
  module SpreeVetfortExtensionV5
    class AiConsultantController < Spree::StoreController
      before_action :ensure_guest_uuid, :set_variant
      before_action :find_or_create_conversation
      before_action :set_conversations

      helper_method :guest_uuid

      def index
      end

      def create
        @message = ai_consultant_params[:message]

        # Persist user message
        @conversation.append_message(role: 'user', content: @message)

        # Enqueue background job; Turbo stream subscription will receive reply
        AiChatJob.perform_later(@conversation.id)
      end

      private

      def ensure_guest_uuid
        cookies.permanent.signed[:vetfort_guest_uuid] ||= SecureRandom.uuid
      end

      def guest_uuid
        cookies.signed[:vetfort_guest_uuid]
      end

      def find_or_create_conversation
        @conversation = conversation_finder.last_active_or_new_conversation
      end

      def set_conversations
        @conversations = conversation_finder.all_for_user
      end

      def conversation_finder
        @conversation_finder ||= ConversationFinder.new(current_user: current_user, guest_uuid: guest_uuid)
      end

      def ai_consultant_params
        params.require(:ai_consultant).permit(:message)
      end
    end
  end
end
