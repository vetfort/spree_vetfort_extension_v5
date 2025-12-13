# frozen_string_literal: true

# VetfortExtensionV5::AiConsultant::MessagesHistoryComponent
module VetfortExtensionV5
  module AiConsultant
    class MessagesHistoryComponent < ApplicationComponent
      attr_reader :messages_target_id, :conversation

      def initialize(messages_target_id:, conversation:)
        @messages_target_id = messages_target_id
        @conversation = conversation
      end

      def display_messages
        conversation.messages.map do |message|
          case message.role
          when 'user'
            VetfortExtensionV5::AiConsultant::CustomerMessageComponent.new(text: message.content, time: message.created_at.strftime('%H:%M'))
          when 'assistant'
            VetfortExtensionV5::AiConsultant::BotMessageComponent.new(text: message.content, time: message.created_at.strftime('%H:%M'), products: message.products)
          end
        end
      end
    end
  end
end
