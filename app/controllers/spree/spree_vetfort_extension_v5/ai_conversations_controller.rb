require 'faker'

module Spree
  module SpreeVetfortExtensionV5
    class AiConversationsController < Spree::StoreController
      before_action :ensure_guest_uuid, :set_variant
      before_action :set_conversations

      helper_method :guest_uuid

      def index
      end

      def create
        ActiveRecord::Base.transaction do
          @conversation = conversation_finder.new_conversation
          @message = ai_consultant_params[:content]
          @conversation.append_message(role: 'user', content: @message)
        end

        AiChatJob.perform_later(@conversation.id)
      end

      def active_conversation
        @conversation = conversation_finder.last_active_or_new_conversation

        html = render_to_string(
          ::VetfortExtensionV5::AiConsultant::MessagesHistoryComponent.new(
            messages_target_id: messages_target_id,
            conversation: @conversation
          )
        )

        render turbo_stream: turbo_stream.replace('messages-history', html: html)
      end

      private

      def ensure_guest_uuid
        cookies.permanent.signed[:vetfort_guest_uuid] ||= SecureRandom.uuid
      end

      def guest_uuid
        cookies.signed[:vetfort_guest_uuid]
      end

      def set_conversations
        @conversations = conversation_finder.all_for_user
      end

      def conversation_finder
        @conversation_finder ||= ConversationFinder.new(current_user: current_user, guest_uuid: guest_uuid)
      end

      def ai_consultant_params
        params.require(:ai_conversation).permit(:content)
      end

      def messages_target_id
        user_identifier = current_user ? "user:#{current_user.id}" : "guest:#{guest_uuid}"
        ['ai_consultant', user_identifier, 'ai-messages'].join(':')
      end
    end
  end
end
