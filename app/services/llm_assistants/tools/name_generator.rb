# frozen_string_literal: true
# LLMAssistants::Tools::NameGenerator
module LLMAssistants
  module Tools
    class NameGenerator
      extend ::Langchain::ToolDefinition

      attr_reader :llm, :summary, :name

      define_function :generate, description: "Generates name for a product based on the product summary."

      def initialize(name:, llm:, summary:)
        @name = name
        @llm = llm
        @summary = summary
      end

      def generate
        prompt = name_prompt_template

        assistant = Langchain::Assistant.new(
          llm: llm,
          instructions: prompt.format(summary: summary, name: name)
        )

        assistant.add_message_and_run!(content: "generate name for the product")
        content = assistant.messages.last&.content

        parsed = JSON.parse(content)

        parsed
      end

      private

      def name_prompt_template
        Langchain::Prompt.load_from_path(
          file_path: File.join(__dir__, '..', 'prompts', 'name_prompt.yaml')
        )
      end
    end
  end
end
