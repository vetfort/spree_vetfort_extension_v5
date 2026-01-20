# frozen_string_literal: true
# query = "что-то для моего кота, он немного грустный, ему нужна игрушка"
# LLMAssistants::Tools::SemanticProductsSearch.new.semantic_search(query:)

require 'bigdecimal'

module LLMAssistants
  module Tools
    class SemanticProductsSearch
      include Spree::Core::Engine.routes.url_helpers
      extend ::Langchain::ToolDefinition

      define_function :semantic_search, description: 'Fetches products using vector similarity (pgvector/neighbor) based on user intent.' do
        property :query, type: 'string', description: 'The user\'s query or intent to search semantically (e.g., "something to calm my nervous cat").'
        property :limit, type: 'integer', required: false, description: 'Max number of products to return (default 5).'
      end

      def semantic_search(query:)
        return JSON.generate([]) if query.to_s.strip.blank?

        query_embedding = embed_query(query)
        return JSON.generate([]) if query_embedding.blank?

        products = nearest_products(query_embedding)
          .take(5)
          .map { |product| serialize_product(product) }

        JSON.generate(products)
      rescue => e
        Langchain.logger.error("SemanticProductsSearch error: #{e.class}: #{e.message}")
        JSON.generate([])
      end

      private

      def embed_query(text)
        embeddings_llm.embed(text: text.to_s).embedding
      rescue => e
        Langchain.logger.warn("[SemanticProductsSearch] Embedding failed: #{e.class}: #{e.message}")
        nil
      end

      def nearest_products(query_embedding)
        scope = Spree::Product.active

        # Neighbor adds `.nearest_neighbors` via `has_neighbors :embedding`.
        if scope.respond_to?(:nearest_neighbors)
          scope.nearest_neighbors(:embedding, query_embedding, distance: 'cosine')
        else
          []
        end
      end

      def serialize_product(decorated_product)
        distance = decorated_product.neighbor_distance
        product = decorated_product.reload

        {
          id: product.id,
          name: product_name(product),
          price: product.display_price.to_s,
          url: product_url(product, host: host),
          distance: distance
        }
      end

      def host
        @host ||= Spree::Store.default.url
      end

      def product_name(product)
        product.name || product.name_ru || product.name_ro || product.name_en
      end

      def embeddings_llm
        @embeddings_llm ||= Langchain::LLM::OpenAI.new(
          api_key: ENV['OPENAI_API_KEY'],
          default_options: {
            model: ENV.fetch('OPENAI_EMBEDDINGS_MODEL', 'text-embedding-3-small')
          }
        )
      end
    end
  end
end
