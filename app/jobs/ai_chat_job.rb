class AiChatJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Spree::VetfortExtensionV5::AiConsultantConversation.find_by(id: conversation_id)
    return if conversation.nil?

    history = conversation.messages
                           .order(:created_at)
                           .pluck(:role, :content)
                           .map { |role, content| { role: role, content: content } }

    result = LLMAssistants::AiConsultantAssistant.new.call(messages: history)
    payload = Array(result).last || {}
    assistant_text = payload[:text].to_s.presence || payload[:content].to_s
    products = Array(payload[:products])
    raw_json = payload[:content].to_s

    message = conversation.messages.create!(
      role: 'assistant',
      content: assistant_text,
      products: products,
      raw_json: raw_json
    )

    Turbo::StreamsChannel.broadcast_append_to(
      "ai_consultant:#{conversation.user_identifier}",
      target: "ai_consultant:#{conversation.user_identifier}:ai-messages",
      renderable: VetfortExtensionV5::AiConsultant::BotMessageComponent.new(
        text: message.content, 
        time: message.created_at.strftime('%H:%M'), 
        products: message.products
      )
    )
  rescue => e
    Langchain.logger.error("AiChatJob error: #{e.class}: #{e.message}")
    fallback = "I'm having trouble right now. Please try again later."
    fallback_message = conversation&.messages&.create!(role: 'assistant', content: fallback, products: [])
    
    if fallback_message && conversation
      Turbo::StreamsChannel.broadcast_append_to(
        "ai_consultant:#{conversation.user_identifier}",
        target: "ai_consultant:#{conversation.user_identifier}:ai-messages",
        renderable: VetfortExtensionV5::AiConsultant::BotMessageComponent.new(
          text: fallback,
          time: fallback_message.created_at.strftime('%H:%M'),
          products: []
        )
      )
    end
  end
end
