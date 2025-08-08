module LLMAssistants
  module Tools
    class TaxonsFetch < ApplicationService
      extend ::Langchain::ToolDefinition

      attr_reader :selected_taxon_ids, :summary, :llm

      define_function :fetch, description: "Selects relevant taxons based on the product summary. Uses user-selected flags as hints and only returns applicable taxons with IDs."

      def initialize(selected_taxon_ids: [], summary: "", llm:)
        @selected_taxon_ids = selected_taxon_ids
        @summary = summary
        @llm = llm
      end

      def fetch
        taxons_json = build_taxons_json
        prompt = taxons_prompt_template

        assistant = Langchain::Assistant.new(
          llm: llm,
          instructions: prompt.format(
            summary: summary,
            taxons_json: taxons_json
          )
        )

        assistant.add_message_and_run!(content: "extract the best taxons based on the summary")
        content = assistant.messages.last&.content

        parsed = JSON.parse(content)

        parsed
      end

      private

      def build_taxons_json
        cache_key = "llm_tools:taxons_fetch:#{selected_taxon_ids.sort.join(',')}:#{Digest::SHA1.hexdigest(summary)}"

        Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
          Spree::Taxon.includes(:parent).map do |taxon|
            {
              id: taxon.id,
              name: taxon.name,
              selected_by_user: selected_taxon_ids.include?(taxon.id)
            }.compact
          end.to_json
        end
      end

      def taxons_prompt_template
        Langchain::Prompt.load_from_path(
          file_path: File.join(__dir__, '..', 'prompts', 'taxons_prompt.yaml')
        )
      end
    end
  end
end
