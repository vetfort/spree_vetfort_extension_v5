# frozen_string_literal: true

module Decorators
  module Spree
    module ProductDecorator
      def self.prepended(base)
        return unless base.column_names.include?('embedding')

        base.has_neighbors :embedding
        base.after_commit :enqueue_embedding_job, on: %i[create]
      rescue StandardError
        # Keep decorator resilient during early boot / migrations.
      end

      private

      def enqueue_embedding_job
        ProductEmbeddingJob.perform_later(id)
      rescue StandardError
        nil
      end
    end
  end
end

::Spree::Product.prepend Decorators::Spree::ProductDecorator
