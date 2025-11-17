# frozen_string_literal: true

# VetfortExtensionV5::AiConsultant::CustomerMessageComponent
module VetfortExtensionV5
  module AiConsultant
    class CustomerMessageComponent < ApplicationComponent
      attr_reader :text, :time

      def initialize(text:, time:)
        @text = text
        @time = time
      end
    end
  end
end
