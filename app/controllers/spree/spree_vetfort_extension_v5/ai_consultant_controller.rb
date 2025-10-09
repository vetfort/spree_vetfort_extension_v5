require 'faker'

module Spree
  module SpreeVetfortExtensionV5
    class AiConsultantController < Spree::StoreController
      before_action :ensure_guest_uuid
      before_action :find_or_create_conversation

      helper_method :guest_uuid


      def create
        @message = ai_consultant_params[:message]

        # Persist user message
        @conversation.append_message(role: 'user', content: @message)

        # Build message history (oldest -> newest)
        history = @conversation.messages.order(created_at: :asc).pluck(:role, :content).map do |role, content|
          { role: role, content: content }
        end

        # Invoke assistant synchronously for now (later move to background job)
        responses = ::LLMAssistants::AiConsultantAssistant.new.call(messages: history)
        assistant_text = Array(responses).last&.dig(:content).to_s

        # Persist assistant response
        @conversation.append_message(role: 'assistant', content: assistant_text)

        # Render via Turbo Stream
        @bot_text = assistant_text
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
