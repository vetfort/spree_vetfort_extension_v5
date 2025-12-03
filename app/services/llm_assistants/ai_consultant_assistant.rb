module LLMAssistants
  class AiConsultantAssistant < ApplicationService
    # Orchestrates the AI shopping consultant conversation.
    # Usage: LLMAssistants::AiConsultantAssistant.call(messages: [...], tools: [...])

    def call(messages:, tools: [])
      tools = Array(tools)
      tools << LLMAssistants::Tools::ProductsFetch.new(llm: llm) if tools.empty?

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

      normalize_assistant_messages(assistant.messages)
    rescue => e
      Langchain.logger.error("AiConsultantAssistant error: #{e.class}: #{e.message}")
      [{ role: 'assistant', content: "I'm having trouble right now. Please try again in a moment." }]
    end

    private

    def llm
      @llm ||= Langchain::LLM::OpenAI.new(
        api_key: ENV['OPENAI_API_KEY'],
        default_options: { model: 'gpt-4o-mini', temperature: 0.3 }
      )
    end

    def ai_consultant_prompt_template
      Langchain::Prompt.load_from_path(
        file_path: File.join(__dir__, 'prompts', 'ai_consultant_instructions.yaml')
      )
    end

    def normalize_assistant_messages(messages)
      Array(messages)
        .select { |m| m.role.to_s == 'assistant' }
        .map { |m| { role: 'assistant', content: m.content.to_s } }
        .last(1) # only the latest response is needed for broadcast
    end
  end
end
