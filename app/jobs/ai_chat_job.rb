class AiChatJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Spree::VetfortExtensionV5::AiConsultantConversation.find_by(id: conversation_id)
    return if conversation.nil?

    history = conversation.messages
                           .order(:created_at)
                           .pluck(:role, :content)
                           .map { |role, content| { role: role, content: content } }

    responses = LLMAssistants::AiConsultantAssistant.new.call(messages: history)
    assistant_text = Array(responses).last&.dig(:content).to_s

    conversation.append_message(role: 'assistant', content: assistant_text)

    Turbo::StreamsChannel.broadcast_append_to(
      "ai_consultant:#{conversation.user_identifier}",
      target: "ai_consultant:#{conversation.user_identifier}:ai-messages",
      partial: 'spree/ai_consultant/bot_message',
      locals: { text: assistant_text }
    )
  rescue => e
    Langchain.logger.error("AiChatJob error: #{e.class}: #{e.message}")
    fallback = "I'm having trouble right now. Please try again later."
    conversation&.append_message(role: 'assistant', content: fallback)
    Turbo::StreamsChannel.broadcast_append_to(
      "ai_consultant:#{conversation_id}",
      target: 'ai-messages',
      partial: 'spree/ai_consultant/bot_message',
      locals: { text: fallback }
    )
  end
end
