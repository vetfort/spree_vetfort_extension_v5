module VetfortExtensionV5
  module AiConsultant
    class BotMessageComponent < ApplicationComponent
      attr_reader :text, :time, :products

      def initialize(text:, time:, products: [])
        @text = text
        @time = time
        @products = Array(products)
      end
    end
  end
end
