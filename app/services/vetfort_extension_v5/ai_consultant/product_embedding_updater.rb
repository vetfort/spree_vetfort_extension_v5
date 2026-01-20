# frozen_string_literal: true

module VetfortExtensionV5
  module AiConsultant
    class ProductEmbeddingUpdater
      def self.call(product_id:)
        new.call(product_id: product_id)
      end

      def call(product_id:)
        product = ::Spree::Product.find_by(id: product_id)
        return unless product

        content = build_search_content(product)
        return if content.blank?

        embedding = embed(content)
        return if embedding.blank?

        product.update!(search_content: content, embedding: embedding)
      end

      private

      def build_search_content(product)
        parts = []
        name = product_name(product)
        parts << name if name.present?

        description = product_description(product)
        parts << description if description.present?

        taxon_names = Array(product&.taxons).first(5).map(&:name).compact_blank
        parts << "Categories: #{taxon_names.join(', ')}" if taxon_names.any?

        parts.join("\n\n").strip
      end

      def product_name(product)
        product.name.presence || product&.name_ru.presence || product&.name_ro.presence || product&.name_en.presence
      end

      def product_description(product)
        product&.description.to_s.strip.presence ||
          product&.description_ru.to_s.strip.presence ||
          product&.description_ro.to_s.strip.presence ||
          product&.description_en.to_s.strip.presence
      end

      def embed(text)
        llm.embed(text: text).embedding
      rescue StandardError => e
        Rails.logger.warn("[ProductEmbeddingUpdater] Embedding failed: #{e.class}: #{e.message}")
        nil
      end

      def llm
        @llm ||= Langchain::LLM::OpenAI.new(
          api_key: ENV['OPENAI_API_KEY'],
          default_options: {
            model: ENV.fetch('OPENAI_EMBEDDINGS_MODEL', 'text-embedding-3-small')
          }
        )
      end
    end
  end
end
