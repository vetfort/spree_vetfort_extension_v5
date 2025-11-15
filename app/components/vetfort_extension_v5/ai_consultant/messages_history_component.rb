# frozen_string_literal: true

# VetfortExtensionV5::AiConsultant::MessagesHistoryComponent
module VetfortExtensionV5
  module AiConsultant
    class MessagesHistoryComponent < ApplicationComponent
      attr_reader :messages_target_id

      def initialize(messages_target_id:)
        @messages_target_id = messages_target_id
      end
    end
  end
end
