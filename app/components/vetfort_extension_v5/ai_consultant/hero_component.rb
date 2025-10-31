# frozen_string_literal: true

# VetfortExtensionV5::AiConsultant::HeroComponent
module VetfortExtensionV5
  module AiConsultant
    class HeroComponent < ApplicationComponent
      def suggestions
        suggestions_list.sample(2)
      end

      private

      def suggestions_list
        t('vetfort.ai_consultant.welcome_component.suggestions_list').values
      end
    end
  end
end
