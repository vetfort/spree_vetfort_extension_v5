# frozen_string_literal: true

# Admin::AiConsultant::CustomerMessageComponent
module Admin
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
