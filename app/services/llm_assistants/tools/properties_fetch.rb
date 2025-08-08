# frozen_string_literal: true
# LLMAssistants::Tools::PropertiesFetch

require 'wikipedia-client'

module LLMAssistants
  module Tools
    class PropertiesFetch < ApplicationService
      extend ::Langchain::ToolDefinition

      attr_reader :selected_property_ids, :summary, :llm

      define_function :fetch, description: "Generates accurate property values based on product summary and guidance. Uses user-selected flags as hints and may consult Wikipedia for factual data."

      def initialize(selected_property_ids: [], summary: "", llm:)
        @selected_property_ids = selected_property_ids
        @summary = summary
        @llm = llm
      end

      def fetch
        prompt = properties_prompt_template

        cache_key = "llm_tools:properties_fetch:#{selected_property_ids.sort.join(',')}:#{Digest::SHA1.hexdigest(summary)}"

        properties_json = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
          Spree::Property.all.map do |prop|
            {
              id: prop.id,
              name: prop.name,
              presentation: prop.presentation,
              kind: prop.kind,
              selected_by_user: selected_property_ids.include?(prop.id),
              guidance_message: guidance_messages_map_for(prop.filter_param)
            }.compact
          end.to_json
        end

        assistant = Langchain::Assistant.new(
          llm: llm,
          instructions: prompt.format(
            summary: summary,
            properties_json: properties_json
          ),
          tools: [Langchain::Tool::Wikipedia.new]
        )

        assistant.add_message_and_run!(content: "extract the best properties based on the summary")
        content = assistant.messages.last&.content

        parsed = JSON.parse(content)

        unless parsed.is_a?(Hash) && parsed.key?("ru") && parsed.key?("ro")
          raise "Unexpected format in PropertiesFetch response: #{parsed.inspect}"
        end

        parsed
      rescue JSON::ParserError => e
        Rails.logger.warn("[PropertiesFetch] JSON parse error: #{e.message}")
        { "ru" => [], "ro" => [] }
      rescue => e
        Rails.logger.error("[PropertiesFetch] LLM failed: #{e.message}")
        { "ru" => [], "ro" => [] }
      end


      def properties_prompt_template
        Langchain::Prompt.load_from_path(
          file_path: File.join(__dir__, '..', 'prompts', 'properties_prompt.yaml')
        )
      end

      def guidance_messages_map_for(property_name)
        {
          'country' => 'Country of origin of the product, e.g. "Poland". Do not guess. Do not use country of sale.',
          'sostav' => 'Full composition list, e.g. "chicken, rice, maize". Use commas, no percentages.',
          'osnovnoy-vkus' => 'Primary flavor, e.g. "chicken", "beef", "salmon".',
          'brend' => 'Brand name of the product, e.g. "Piper Adult". Use exact brand name, not variations.',
          'klass-korma' => 'Class of the product, e.g. "premium", "super premium", "economy".',
          'razmer-zhivotnogo' => 'Animal size this product is intended for, e.g. "small", "medium", "large". Never use life stages like "sterilised".',
          'tip-korma' => 'Format of the food, e.g. "dry food", "wet food", "treat".',
          'forma-vypuska' => 'Physical form of product, e.g. "pills", "powder", "chews", "liquid".',
          'spetsialnie_dobavki' => 'Special additives if present, e.g. "L-carnitine", "taurine", "Omega-3". Use only known ingredients.',
          'naznachenie' => 'Main functional purpose, e.g. "weight control", "urinary care", "hairball prevention".',
          'osnovnye-ingredienty' => 'Main ingredients (not full list), e.g. "chicken, rice". Max 2–3.',
          'lechebnaya-dieta' => 'Therapeutic diet type, e.g. "renal", "gastrointestinal", "dermatologic". Use only if truly veterinary.',
          'vozrast' => 'Target age group, e.g. "kitten", "adult", "senior". Do not mix with sterilised, size, or breed.'
        }[property_name]
      end
    end
  end
end
