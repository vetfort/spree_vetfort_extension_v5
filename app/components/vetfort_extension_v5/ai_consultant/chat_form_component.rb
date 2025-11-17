# frozen_string_literal: true

# VetfortExtensionV5::AiConsultant::ChatFormComponent
module VetfortExtensionV5
  module AiConsultant
    class ChatFormComponent < ApplicationComponent
      attr_reader :conversation

      def initialize(conversation:)
        @conversation = conversation
      end
    end
  end
end
