# frozen_string_literal: true

require "json"
require "action_view"

module AiSearchable
  class ProductTagger

    DIMENSION_ALIASES = {
      "problems" => "problem"
    }.freeze

    attr_reader :llm, :brand_normalizer

    def initialize(llm: default_llm)
      @llm = llm
      @brand_normalizer = AiSearchable::BrandNormalizer.new
    end

    def apply!(product:)
      ai_tags = generate_ai_tags(product: product)
      tag_strings = build_tag_strings(ai_tags)
      return [] if tag_strings.empty?

      product.tag_list.add(tag_strings)
      product.save!
      tag_strings
    end

    private

    def generate_ai_tags(product:)
      prompt = prompt_template.format(
        ai_schema: ai_schema_description,
        product_context: product_context(product)
      )

      response = llm.chat(
        messages: [{ role: "user", content: prompt }],
        response_format: { type: "json_object" }
      ).completion

      parsed = JSON.parse(response)
      normalize_ai_tags(parsed["ai_tags"] || {})
    rescue => e
      Rails.logger.error("AiSearchable::ProductTagger failed for product ##{product.id}: #{e.message}")
      {}
    end

    def prompt_template
      Langchain::Prompt.load_from_path(
        file_path: File.join(__dir__, "prompts", "product_tagger_prompt.yaml")
      )
    end

    def ai_schema_description
      schema.map do |dimension, cfg|
        values = Array(cfg[:values])
        multiplicity = multiple_dimensions.include?(dimension.to_s) ? "multiple allowed" : "single value"
        if cfg[:type] == "enum"
          "- #{dimension}: choose #{multiplicity} from [#{values.join(", ")}]"
        else
          "- #{dimension}: free-form lowercase string (#{multiplicity})"
        end
      end.join("\n")
    end

    def schema
      @schema ||= AiSearchable::Config.to_llm_schema
    end

    def multiple_dimensions
      @multiple_dimensions ||= %w[species problem]
    end

    def product_context(product)
      parts = [
        "Name: #{product.name}",
        ("SKU: #{product.try(:sku) || product.try(:master)&.sku}" if product.respond_to?(:sku) || product.respond_to?(:master)),
        formatted_description(product),
        formatted_taxons(product),
        formatted_properties(product)
      ].compact_blank

      parts.join("\n")
    end

    def formatted_description(product)
      description = product.try(:description).to_s
      return if description.blank?

      sanitized = ActionView::Base.full_sanitizer.sanitize(description)
      "Description: #{sanitized.tr("\n", " ").squish}"
    end

    def formatted_taxons(product)
      return unless product.respond_to?(:taxons)

      names = Array(product.taxons).map { |t| t.try(:name).to_s }.compact_blank
      return if names.empty?

      "Taxons: #{names.join(", ")}"
    end

    def formatted_properties(product)
      return unless product.respond_to?(:product_properties)

      pairs = Array(product.product_properties).map do |pp|
        next if pp.property.nil?

        [pp.property.presentation, pp.value.presence || pp.property.name].compact.join(": ")
      end.compact_blank

      return if pairs.empty?

      "Properties: #{pairs.join("; ")}"
    end

    def normalize_ai_tags(ai_tags)
      normalized = ai_tags.each_with_object({}) do |(dimension, values), acc|
        normalized_dimension = normalize_dimension(dimension)
        next unless normalized_dimension

        normalized_values = normalized_values_for(normalized_dimension, values)
        next if normalized_values.empty?

        acc[normalized_dimension] = if multiple_dimensions.include?(normalized_dimension)
          normalized_values
        else
          normalized_values.first
        end
      end

      product_type = normalized["product_type"]
      if product_type.present? && !%w[food supplement].include?(product_type)
        normalized.except!("format", "diet", "problem")
      end

      normalized
    end

    def normalize_dimension(dimension)
      dim = dimension.to_s
      normalized = DIMENSION_ALIASES.fetch(dim, dim)
      return normalized if AiSearchable::Config.dimensions.include?(normalized)
    end

    def normalized_values_for(dimension, values)
      Array(values).compact_blank.map do |value|
        normalized = if dimension == "brand"
          brand_normalizer.normalize(value) || AiSearchable::TagFormat.normalize_value(value)
        else
          AiSearchable::TagFormat.normalize_value(value)
        end

        next if normalized.blank?
        next normalized if AiSearchable::Config.allow_any?(dimension)

        allowed = AiSearchable::Config.values_for(dimension)
        next unless allowed.include?(normalized)

        normalized
      end.compact
    end

    def build_tag_strings(ai_tags)
      ai_tags.flat_map do |dimension, values|
        Array(values).map { |value| AiSearchable::TagFormat.build(dimension, value) }
      end
    end

    def default_llm
      Langchain::LLM::OpenAI.new(
        api_key: ENV.fetch("OPENAI_API_KEY"),
        default_options: { model: "gpt-4o-mini", temperature: 0.2 }
      )
    end
  end
end
