module LLMAssistants
  class ProductDataExtractor < ApplicationService
    def call(row:)
      product_attributes = extract_product_attributes(row:)
      summary = summary_for(
        row.processed_data['external_url'],
        user_description: row.processed_data['description'] || ''
      )

      parser = output_parser

      template = prompt_template

      assistant = Langchain::Assistant.new(
        llm: llm,
        instructions: template.template,
        tools: tools(row, summary: summary)
      )

      formatted_prompt = template.format(
        product_name: row.processed_data['name'],
        external_url: row.processed_data['external_url'] || '',
        store_name: "VetFort",
        page_summary: summary,
        user_description: row.processed_data['description'] || ''
      )

      assistant.add_message_and_run!(content: formatted_prompt)
      llm_response = assistant.messages.last&.content

      parsed = parse_response(llm_response, parser)

      if parsed.failure? && parsed.failure.is_a?(Langchain::OutputParsers::OutputParserException)
        fix_parser = Langchain::OutputParsers::OutputFixingParser.from_llm(llm: llm, parser: parser)
        fixed = with_rescue { fix_parser.parse(llm_response) }

        return fixed.fmap { |val| Structs::ProductAttributesResponseStruct.new(val.merge(product_attributes)) }
      end

      parsed.fmap { |val| Structs::ProductAttributesResponseStruct.new(val.merge(product_attributes)) }
    rescue => e
      Failure("LLM call failed: #{e.message}")
    end

    private

    def summary_for(url, user_description: '')
      cache_key = Digest::SHA1.hexdigest([url.to_s, user_description.to_s].join(':'))

      return summarize_from_description(user_description) if url.blank?

      Rails.cache.fetch("llm:summary:#{cache_key}", expires_in: 1.hour) do
        LLMAssistants::Tools::UrlFetch.new(llm: llm).invoke(url: url, user_description: user_description)
      end
    end

    def summarize_from_description(user_description)
      return "" if user_description.blank?

      prompt = Langchain::Prompt.load_from_path(
        file_path: File.join(__dir__, 'prompts', 'url_summary_prompt.yaml')
      )

      assistant = Langchain::Assistant.new(
        llm: llm,
        instructions: prompt.format(url: '', content: '', user_description: user_description),
        tools: []
      )

      assistant.add_message_and_run!(content: "analyze and summarize")
      assistant.messages.last&.content.to_s
    end

    def extract_product_attributes(row:)
      {
        sku: row.processed_data['sku'],
        price: row.processed_data['price'].to_f,
        shipping_category: Spree::ShippingCategory.find_by(name: 'Default'),
        external_url: row.processed_data['external_url'] || '',
        images: row.processed_data['images'] || []
      }
    end

    def tools(row, summary:)
      # selected_option_type_ids = selected_ids_for(row, 'options')
      selected_property_ids = selected_ids_for(row, 'properties')
      selected_taxon_ids = selected_ids_for(row, 'taxons')
      name = row.processed_data['name']

      [
        # LLMAssistants::Tools::OptionTypesFetch.new(
        #   selected_option_type_ids: selected_option_type_ids,
        #   summary: summary,
        #   llm: llm
        # ),
        LLMAssistants::Tools::PropertiesFetch.new(
          selected_property_ids: selected_property_ids,
          summary: summary,
          llm: llm
        ),
        LLMAssistants::Tools::TaxonsFetch.new(
          selected_taxon_ids: selected_taxon_ids,
          summary: summary,
          llm: llm
        ),
        LLMAssistants::Tools::TagsGenerator.new(
          summary: summary,
          llm: llm
        ),
        LLMAssistants::Tools::NameGenerator.new(
          name: name,
          summary: summary,
          llm: llm
        )
      ]
    end

    def selected_ids_for(row, key)
      selected = Array(row.processed_data[key]).map(&:to_i).uniq
      common = Array(row.common_values[key]).map(&:to_i).uniq
      common.concat(selected).compact.uniq
    end

    def parse_response(llm_response, parser)
      with_rescue { parser.parse(llm_response) }
    end

    def llm
      @llm ||= Langchain::LLM::OpenAI.new(
        api_key: ENV["OPENAI_API_KEY"],
        default_options: { model: "gpt-4o", temperature: 0.4 }
      )
    end

    def prompt_template
      Langchain::Prompt.load_from_path(
        file_path: File.join(__dir__, 'prompts', 'product_import_prompt.yaml')
      )
    end

    def output_parser
      Langchain::OutputParsers::StructuredOutputParser.from_json_schema(
        {
          type: "object",
          properties: {
            ru: {
              type: "object",
              properties: {
                name: { type: "string", minLength: 1 },
                description: { type: "string", minLength: 1 },
                meta_title: { type: "string", minLength: 1 },
                meta_description: { type: "string", minLength: 1 },
                meta_keywords: { type: "string", minLength: 1 },
                properties: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      id: { type: "integer" },
                      value: { type: "string", minLength: 1 }
                    },
                    required: %w[id value]
                  }
                }
              },
              required: %w[description meta_title meta_description meta_keywords properties]
            },
            ro: {
              type: "object",
              properties: {
                name: { type: "string", minLength: 1 },
                description: { type: "string", minLength: 1 },
                meta_title: { type: "string", minLength: 1 },
                meta_description: { type: "string", minLength: 1 },
                meta_keywords: { type: "string", minLength: 1 },
                properties: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      id: { type: "integer" },
                      value: { type: "string", minLength: 1 }
                    },
                    required: %w[id value]
                  }
                }
              },
              required: %w[description meta_title meta_description meta_keywords properties]
            },
            options: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  id: { type: "integer" },
                  values: {
                    type: "array",
                    items: { type: "integer" }
                  }
                },
                required: %w[id values]
              }
            },
            taxons: {
              type: "array",
              items: { type: "integer" }
            },
            tags: {
              type: "array",
              items: { type: "string" },
              minItems: 1,
              maxItems: 5
            }
          },
          required: %w[ru ro options taxons tags]
        }
      )
    end
  end
end
