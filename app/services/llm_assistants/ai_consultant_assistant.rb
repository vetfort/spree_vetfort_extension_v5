module LLMAssistants
  class AiConsultantAssistant < ApplicationService
    # Orchestrates the AI shopping consultant conversation.
    # Returns JSON with structured text and products
    # Usage: LLMAssistants::AiConsultantAssistant.call(messages: [...], tools: [...])

    def self.call(messages:, tools: [])
      new.call(messages: messages, tools: tools)
    end

    def call(messages:)
      tools = [].tap do |tools_list|
        tools_list << LLMAssistants::Tools::ProductsFetch.new(llm: llm)
        tools_list << LLMAssistants::Tools::SemanticProductsSearch.new
      end

      instructions = ai_consultant_prompt_template.template
      assistant = Langchain::Assistant.new(
        llm: llm,
        instructions: instructions,
        tools: tools
      )

      messages_array = Array(messages)
      last_user_index = messages_array.rindex { |m| (m[:role] || m['role']).to_s == 'user' }

      messages_array.each_with_index do |msg, index|
        next if msg.nil? || index == last_user_index

        role = msg[:role] || msg['role']
        content = msg[:content] || msg['content']
        next if role.blank? || content.blank?

        assistant.add_message(role: role.to_s, content: content.to_s)
      end

      if last_user_index
        last_user = messages_array[last_user_index]
        content = last_user[:content] || last_user['content']
        assistant.add_message_and_run!(content: content.to_s) if content.present?
      end

      parse_structured_response(assistant.messages)
    rescue => e
      Langchain.logger.error("AiConsultantAssistant error: #{e.class}: #{e.message}")
      fallback_text = "I'm having trouble right now. Please try again in a moment."
      [{ role: 'assistant', content: fallback_text, text: fallback_text, products: [] }]
    end

    private

    def llm
      @llm ||= Langchain::LLM::OpenAI.new(
        api_key: ENV['OPENAI_API_KEY'],
        default_options: {
          model: 'gpt-4o-mini',
          temperature: 0.3,
          response_format: { type: 'json_object' }
        }
      )
    end

    def ai_consultant_prompt_template
      Langchain::Prompt.load_from_path(
        file_path: File.join(__dir__, 'prompts', 'ai_consultant_instructions.yaml')
      )
    end

    def parse_structured_response(messages)
      assistant_message = Array(messages).select { |m| m.assistant? }.last
      return fallback_response unless assistant_message

      response_content = assistant_message.content.to_s
      
      begin
        parsed = JSON.parse(response_content)
        text = parsed['text'].to_s
        products = Array(parsed['products']).compact
        
        [{ role: 'assistant', content: response_content, text: text, products: products }]
      rescue JSON::ParserError => e
        Langchain.logger.warn("Failed to parse JSON response: #{e.message}")
        Langchain.logger.warn("Response was: #{response_content}")
        fallback_response
      end
    end

    def fallback_response
      fallback_text = "I'm having trouble right now. Please try again in a moment."
      [{ role: 'assistant', content: fallback_text, text: fallback_text, products: [] }]
    end
  end
end
