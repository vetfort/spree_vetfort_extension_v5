# frozen_string_literal: true

module AiSearchable
  class Config
    CONFIG_PATH = SpreeVetfortExtensionV5::Engine.root.join("config/ai_searchable.yml")
    MULTIPLE_DIMENSIONS = %w[species problem].freeze

    class << self
      def raw
        @raw ||= YAML.load_file(CONFIG_PATH).fetch("ai_searchable")
      end

      def dimensions
        raw.keys
      end

      def values_for(dimension)
        dim = raw[dimension.to_s]
        return [] unless dim

        Array(dim["values"]).map(&:to_s)
      end

      def allow_any?(dimension)
        dim = raw[dimension.to_s]
        dim && dim["allow_any"] == true
      end

      # Returns a hash suitable for building an LLM tool schema
      #
      # Example:
      # {
      #   species: { type: "enum", values: ["dog", "cat", ...], multiple: true },
      #   brand:   { type: "string", multiple: false }
      # }
      def to_llm_schema
        raw.each_with_object({}) do |(dimension, cfg), acc|
          multiple = MULTIPLE_DIMENSIONS.include?(dimension.to_s)

          if cfg["allow_any"]
            acc[dimension.to_sym] = { type: "string", multiple: multiple }
          else
            acc[dimension.to_sym] = { type: "enum", values: Array(cfg["values"]), multiple: multiple }
          end
        end
      end
    end
  end
end
