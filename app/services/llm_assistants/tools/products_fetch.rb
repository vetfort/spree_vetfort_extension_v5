# frozen_string_literal: true
# LLMAssistants::Tools::ProductsFetch

require "bigdecimal"

module LLMAssistants
  module Tools
    class ProductsFetch
      include Spree::Core::Engine.routes.url_helpers
      extend ::Langchain::ToolDefinition

      define_function :fetch, description: "Fetches products by mapping user intent to AI tags." do
        property :user_intent, type: "string", description: "The user's search query or intent (e.g. 'food for my puppy')."
      end

      attr_reader :llm

      def initialize(llm:)
        @llm = llm
      end

      def fetch(user_intent:)
        prompt = products_prompt_template.format(
          user_intent: user_intent,
          ai_dimensions: ai_dimensions_description
        )

        response = llm.chat(
          messages: [{ role: "user", content: prompt }],
          response_format: { type: "json_object" }
        ).completion

        parsed_response = JSON.parse(response)
        ai_tags = parsed_response["ai_tags"] || {}
        search_query = parsed_response["search_query"].to_s.strip

        products = search_products(ai_tags)
        return JSON.generate(products) if products.any?

        if search_query.present? && search_query != user_intent
          result = fallback_search(search_query)
          return result unless result == "[]"
        end

        fallback_search(user_intent)
      rescue => e
        Langchain.logger.error("ProductsFetch error: #{e.message}")
        JSON.generate([])
      end

      private

      def products_prompt_template
        Langchain::Prompt.load_from_path(
          file_path: File.join(__dir__, '..', 'prompts', 'products_prompt.yaml')
        )
      end

      def ai_dimensions_description
        AiSearchable::Config.to_llm_schema.map do |dimension, cfg|
          if cfg[:type] == "enum"
            values = Array(cfg[:values]).join(', ')
            multiplicity = cfg[:multiple] ? "multiple allowed" : "single value"
            "- #{dimension}: choose #{multiplicity} from [#{values}]"
          else
            "- #{dimension}: free-form string (single value)"
          end
        end.join("\n")
      end

      def search_products(ai_tags)
        search_params = build_search_params(ai_tags)
        return [] if search_params.values.all?(&:blank?)

        ProductSearch.new(**search_params, limit: 10).call.map do |product|
          serialize_product(product)
        end
      end

      def build_search_params(ai_tags)
        {
          species: normalize_list(ai_tags["species"]),
          format: normalize_list(ai_tags["format"]),
          diet: normalize_list(ai_tags["diet"]),
          problems: normalize_list(ai_tags["problems"]),
          brand: normalize_brand(ai_tags["brand"]),
          max_price: normalize_price(ai_tags["max_price"])
        }
      end

      def normalize_list(values)
        Array(values).compact_blank.map { |v| AiSearchable::TagFormat.normalize_value(v) }
      end

      def normalize_tag_value(value)
        return if value.blank?

        AiSearchable::TagFormat.normalize_value(value)
      end

      def normalize_free_value(value)
        value.to_s.strip.presence
      end

      def normalize_brand(value)
        raw = normalize_free_value(value)
        return if raw.blank?

        normalized = AiSearchable::BrandNormalizer.new.normalize(raw)
        normalized.presence
      end

      def normalize_price(value)
        return if value.blank?

        BigDecimal(value.to_s)
      rescue ArgumentError
        nil
      end

      def serialize_product(product)
        {
          id: product.id,
          name: product_name(product),
          price: product.display_price.to_s,
          url: product_url(product, host: host)
        }
      end

      def fallback_search(query)
        products = Spree::Product.active
          .joins(:variants_including_master)
          .joins("LEFT OUTER JOIN spree_product_translations ON spree_product_translations.spree_product_id = spree_products.id")
          .where(
            "LOWER(spree_product_translations.name) ILIKE :q OR LOWER(spree_variants.sku) ILIKE :q",
            q: "%#{query.downcase}%"
          )
          .distinct
          .limit(5)
          .map { |product| serialize_product(product) }

        JSON.generate(products)
      end
 
      def host
        @host ||= Spree::Store.default.url
      end

      def product_name(product)
        product.name || product.name_ru ||  product.name_ro || product.name_en
      end
    end
  end
end
