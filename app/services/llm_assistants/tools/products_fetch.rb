# frozen_string_literal: true
# LLMAssistants::Tools::ProductsFetch

module LLMAssistants
  module Tools
    class ProductsFetch
      extend ::Langchain::ToolDefinition

      define_function :fetch, description: "Fetches products by mapping user intent to existing tags." do
        property :user_intent, type: "string", description: "The user's search query or intent (e.g. 'food for my puppy')."
      end

      attr_reader :llm

      def initialize(llm:)
        @llm = llm
      end

      def fetch(user_intent:)
        # 1. Retrieve all available tags to provide context
        available_tags = Rails.cache.fetch('ai_consultant:available_tags', expires_in: 1.hour) do
          ActsAsTaggableOn::Tag.distinct.for_context(:tags).pluck(:name).join(", ")
        end

        if available_tags.blank?
          # Fallback if no tags exist: basic search
          return fallback_search(user_intent)
        end

        # 2. Ask LLM to select relevant tags
        prompt = products_prompt_template.format(
          user_intent: user_intent,
          available_tags: available_tags
        )

        # Using a temporary chat to get the JSON response
        response = llm.chat(
          messages: [{ role: "user", content: prompt }],
          response_format: { type: "json_object" }
        ).completion

        parsed_response = JSON.parse(response)
        selected_tags = parsed_response["selected_tags"] || []

        # 3. Fetch products matching those tags
        # Using 'match_all: true' for stricter relevance, or fallback to ANY if needed.
        # We also add a keyword search layer for things like Brand names if tags miss them.
        scope = Spree::Product.includes(:master, :taxons, :variants)

        if selected_tags.any?
          # Adjust syntax based on your tagging library. usually:
          scope = scope.tagged_with(selected_tags)
        end

        # Limit results to keep context small
        products = scope.limit(10).map do |product|
          {
            id: product.id,
            name: product.name,
            price: product.display_price.to_s,
            url: "/products/#{product.slug}",
            tags: product.tag_list.to_a
          }
        end

        JSON.generate(products)
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

      def fallback_search(query)
        products = Spree::Product.active
                                 .ransack(name_or_description_cont: query)
                                 .result
                                 .limit(5)
                                 .map { |p| { id: p.id, name: p.name, price: p.display_price.to_s } }
        JSON.generate(products)
      end
    end
  end
end
