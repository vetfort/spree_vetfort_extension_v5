module LLMAssistants
  module Tools
    class OptionTypesFetch
      extend ::Langchain::ToolDefinition

      attr_reader :selected_option_type_ids, :summary, :llm

      define_function :fetch, description: "Selects relevant option types and values based on the product summary. Uses user-selected flags as hints and only returns applicable options with value IDs."

      def initialize(selected_option_type_ids: [], summary: "", llm:)
        @selected_option_type_ids = selected_option_type_ids.map(&:to_i)
        @summary = summary
        @llm = llm
      end

      def fetch
        prompt = option_types_prompt_template
        options_json = build_options_json

        assistant = Langchain::Assistant.new(
          llm: llm,
          instructions: prompt.format(
            summary: summary,
            options_json: options_json
          )
        )

        assistant.add_message_and_run!(content: "extract the best option types based on the summary")
        content = assistant.messages.last&.content

        parsed = JSON.parse(content)
      end

      private

      def build_options_json
        cache_key = "llm_tools:option_types_fetch:#{selected_option_type_ids.sort.join(',')}:#{Digest::SHA1.hexdigest(summary)}"

        Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
          Spree::OptionType.includes(:option_values).map do |type|
            {
              option_type_id: type.id,
              presentation: type.presentation,
              option_values: type.option_values.map do |value|
                {
                  option_value_id: value.id,
                  name: value.name
                }
              end,
              selected_by_user: selected_option_type_ids.include?(type.id)
            }
          end.to_json
        end
      end

      def option_types_prompt_template
        Langchain::Prompt.load_from_path(
          file_path: File.join(__dir__, '..', 'prompts', 'option_types_prompt.yaml')
        )
      end
    end
  end
end
