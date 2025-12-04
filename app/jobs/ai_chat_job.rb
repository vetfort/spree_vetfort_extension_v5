class AiChatJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Spree::VetfortExtensionV5::AiConsultantConversation.find_by(id: conversation_id)
    return if conversation.nil?

    history = conversation.messages
                           .order(:created_at)
                           .pluck(:role, :content)
                           .map { |role, content| { role: role, content: content } }

    result = LLMAssistants::AiConsultantAssistant.call(messages: history)
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
      partial: 'spree/ai_consultant/bot_message',
      locals: { text: assistant_text }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "ai_consultant:#{conversation.user_identifier}",
      target: "ai_consultant:#{conversation.user_identifier}:ai-products",
      partial: 'spree/ai_consultant/products_grid',
      locals: { products: message.products }
    )
  rescue => e
    Langchain.logger.error("AiChatJob error: #{e.class}: #{e.message}")
    fallback = "I'm having trouble right now. Please try again later."
    conversation&.messages&.create!(role: 'assistant', content: fallback, products: [])
    Turbo::StreamsChannel.broadcast_append_to(
      "ai_consultant:#{conversation_id}",
      target: 'ai-messages',
      partial: 'spree/ai_consultant/bot_message',
      locals: { text: fallback }
    )
  end
end
