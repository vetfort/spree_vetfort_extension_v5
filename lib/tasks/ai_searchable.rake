# frozen_string_literal: true

namespace :ai_searchable do
  desc "Populate ai_searchable tags for products using the LLM"
  task populate: :environment do
    llm = Langchain::LLM::OpenAI.new(
      api_key: ENV["OPENAI_API_KEY"],
      default_options: { model: "gpt-4o-mini", temperature: 0.2 }
    )

    tagger = AiSearchable::ProductTagger.new(llm: llm)

    scope = Spree::Product.includes(:taxons, :product_properties, :taggings)

    scope.find_each do |product|
      puts "[ai_searchable] Tagging product ##{product.id} (#{product.name})"
      tags = tagger.apply!(product: product)

      if tags.empty?
        puts "  -> no tags generated"
      else
        puts "  -> added tags: #{tags.join(', ')}"
      end
    rescue => e
      warn "  -> failed: #{e.message}"
    end
  end
end
