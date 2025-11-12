# frozen_string_literal: true

# VetfortExtensionV5::AiConsultant::ChatComponent
module VetfortExtensionV5
  module AiConsultant
    class ChatComponent < ApplicationComponent
      attr_reader :current_user, :cookies

      def initialize(current_user:, cookies:)
        @current_user = current_user
        @cookies = cookies
      end

      private

      def turbo_stream_identifier
        ['ai_consultant', user_identifier].join(':')
      end

      def messages_target_id
        ['ai_consultant', user_identifier, 'ai-messages'].join(':')
      end

      def user_identifier
        current_user ? "user:#{current_user.id}" : "guest:#{cookies.signed[:vetfort_guest_uuid]}"
      end
    end
  end
end
