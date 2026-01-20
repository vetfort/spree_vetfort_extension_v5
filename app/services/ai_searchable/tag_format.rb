# frozen_string_literal: true

# AiSearchable::TagFormat is a helper for working with ai_searchable tags.
module AiSearchable
  class TagFormat
    AI_PREFIX = "ai_searchable"

    class << self
      def build(dimension, value)
        "#{AI_PREFIX}:#{dimension}:#{normalize_value(value)}"
      end

      def parse(tag_string)
        parts = tag_string.to_s.split(":")
        return nil unless parts.size == 3 && parts.first == AI_PREFIX

        {
          dimension: parts[1],
          value: parts[2]
        }
      end

      def normalize_value(value)
        return "" if value.blank?

        value.to_s.strip.downcase.gsub(/\s+/, "_")
      end
    end
  end
end
