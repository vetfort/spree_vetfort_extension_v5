require 'faker'

module Spree
  module SpreeVetfortExtensionV5
    class AiConsultantController < Spree::StoreController
      before_action :ensure_guest_uuid, :set_variant
      before_action :find_or_create_conversation

      helper_method :guest_uuid


      def create
        @message = ai_consultant_params[:message]

        # Persist user message
        @conversation.append_message(role: 'user', content: @message)

        # Enqueue background job; Turbo stream subscription will receive reply
        AiChatJob.perform_later(@conversation.id)

        # Optional immediate UX feedback (spinner) — keep existing behavior minimal
        @bot_text = "Processing…"
      end

      private

      def ensure_guest_uuid
        cookies.permanent.signed[:vetfort_guest_uuid] ||= SecureRandom.uuid
      end

      def guest_uuid
        cookies.signed[:vetfort_guest_uuid]
      end

      def find_or_create_conversation
        user_identifier = current_user.present? ? "user:#{current_user.id}" : "guest:#{guest_uuid}"

        @conversation = ::Spree::VetfortExtensionV5::AiConsultantConversation.find_or_create_by(user_identifier: user_identifier)
      end

      def ai_consultant_params
        params.require(:ai_consultant).permit(:message)
      end
    end
  end
end
