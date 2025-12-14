require 'faker'

module Spree
  module SpreeVetfortExtensionV5
    class AiConversationsController < Spree::StoreController
      before_action :ensure_guest_uuid
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

        respond_to do |format|
          format.turbo_stream { render turbo_stream: [], status: :accepted }
          format.json { render json: { ok: true }, status: :accepted }
          format.any { head :accepted }
        end
      end

      def active_conversation
        @conversation = conversation_finder.last_active_or_new_conversation

        render turbo_stream: [
          turbo_stream.replace('messages-history') do
            render_to_string(
              ::VetfortExtensionV5::AiConsultant::MessagesHistoryComponent.new(
                messages_target_id: messages_target_id,
                conversation: @conversation
              )
            )
          end
        ]
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
        @conversation_finder ||= ConversationFinder.new(
          current_user: try(:current_spree_user) || try(:current_user),
          guest_uuid: guest_uuid
        )
      end

      def ai_consultant_params
        if params[:ai_conversation].present?
          params.require(:ai_conversation).permit(:content)
        else
          params.permit(:content)
        end
      end

      def messages_target_id
        user = try(:current_spree_user) || try(:current_user)
        user_identifier = user ? "user:#{user.id}" : "guest:#{guest_uuid}"
        ['ai_consultant', user_identifier, 'ai-messages'].join(':')
      end
    end
  end
end
