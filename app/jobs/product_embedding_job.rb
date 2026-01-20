# frozen_string_literal: true

class ProductEmbeddingJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(product_id)
    VetfortExtensionV5::AiConsultant::ProductEmbeddingUpdater.call(product_id: product_id)
  end
end
