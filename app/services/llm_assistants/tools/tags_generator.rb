# frozen_string_literal: true
# LLMAssistants::Tools::TagsGenerator
module LLMAssistants
  module Tools
    class TagsGenerator
      extend ::Langchain::ToolDefinition

      attr_reader :llm, :summary

      define_function :generate, description: "Generates tags for a product based on the product summary."

      def initialize(llm:, summary:)
        @llm = llm
        @summary = summary
      end

      def generate
        prompt = tags_prompt_template

        assistant = Langchain::Assistant.new(
          llm: llm,
          instructions: prompt.format(summary: summary, today: Date.today.strftime('%d.%m.%y'))
        )

        assistant.add_message_and_run!(content: "generate tags for the product")
        content = assistant.messages.last&.content

        parsed = JSON.parse(content)

        unless parsed.include?(Date.today.strftime('%d.%m.%y'))
          parsed << Date.today.strftime('%d.%m.%y')
        end

        parsed
      end

      private

      def tags_prompt_template
        Langchain::Prompt.load_from_path(
          file_path: File.join(__dir__, '..', 'prompts', 'tags_prompt.yaml')
        )
      end
    end
  end
end
