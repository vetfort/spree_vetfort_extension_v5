module VetfortExtensionV5
  module AiConsultant
    class BotMessageComponent < ApplicationComponent
      attr_reader :text, :time

      def initialize(text:, time:)
        @text = text
        @time = time
      end
    end
  end
end
