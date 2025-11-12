# frozen_string_literal: true

# VetfortExtensionV5::AiConsultant::ChatComponent
module VetfortExtensionV5
  module AiConsultant
    class ChatDialogComponent < ApplicationComponent
      attr_reader :turbo_stream_identifier, :messages_target_id

      def initialize(turbo_stream_identifier:, messages_target_id:)
        @turbo_stream_identifier = turbo_stream_identifier
        @messages_target_id = messages_target_id
      end
    end
  end
end
