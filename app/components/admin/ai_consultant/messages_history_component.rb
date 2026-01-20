# frozen_string_literal: true

# Admin::AiConsultant::MessagesHistoryComponent
module Admin
  module AiConsultant
    class MessagesHistoryComponent < ApplicationComponent
      attr_reader :conversation

      def initialize(conversation:)
        @conversation = conversation
      end

      def display_messages
        conversation.messages.map do |message|
          case message.role
          when 'user'
            Admin::AiConsultant::CustomerMessageComponent.new(text: message.content, time: message.created_at.strftime('%H:%M'))
          when 'assistant'
            Admin::AiConsultant::BotMessageComponent.new(text: message.content, time: message.created_at.strftime('%H:%M'), products: message.products)
          end
        end
      end
    end
  end
end
