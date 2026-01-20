module Vetfort
  module Console
    def ai_consultant_conversation
      Spree::VetfortExtensionV5::AiConsultantConversation
    end
    alias_method :conversation, :ai_consultant_conversation
  end
end
