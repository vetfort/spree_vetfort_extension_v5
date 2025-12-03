# frozen_string_literal: true

class ProductAttributes
  attr_reader :product

  def initialize(product)
    @product = product
  end

  def to_h
    {
      species:  extract_multi_enum("species"),
      format:   extract_single_enum("format"),
      diet:     extract_single_enum("diet"),
      problems: extract_multi_enum("problem"),
      brand:    extract_brand
    }
  end

  private

  def ai_tags
    @ai_tags ||= Array(product.tag_list).map(&:to_s)
  end

  def parsed_ai_tags
    @parsed_ai_tags ||= ai_tags.filter_map do |tag|
      parsed = AiSearchable::TagFormat.parse(tag)
      next unless parsed

      parsed.merge(raw: tag)
    end
  end

  def extract_single_enum(dimension)
    tag = parsed_ai_tags.find { |t| t[:dimension] == dimension }
    return nil unless tag

    tag[:value].to_sym
  end

  def extract_multi_enum(dimension)
    parsed_ai_tags
      .select { |t| t[:dimension] == dimension }
      .map { |t| t[:value].to_sym }
      .uniq
  end

  def extract_brand
    tag = parsed_ai_tags.find { |t| t[:dimension] == "brand" }
    return nil unless tag

    tag[:value].to_sym
  end
end

