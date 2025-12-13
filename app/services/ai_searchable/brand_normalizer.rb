require 'yaml'

# AiSearchable::BrandNormalizer
module AiSearchable
  class BrandNormalizer
    CONFIG_PATH = SpreeVetfortExtensionV5::Engine.root.join("config/ai_searchable.yml")

    def initialize
      @config = YAML.load_file(CONFIG_PATH).fetch("ai_searchable")
      @brand_cfg = @config.dig('brand') || {}
      @values = Array(@brand_cfg['values']).map(&:to_s)
      @aliases = @brand_cfg['aliases'] || {}
    end

    # Normalize arbitrary brand text to a canonical value from `values`,
    # using aliases when provided. Returns nil if no match.
    def normalize(text)
      return nil if text.nil?
      key = canonicalize(text)

      return key if @values.include?(key)

      # search alias mappings
      @aliases.each do |canonical, variants|
        variants = Array(variants).map { |v| canonicalize(v) }
        return canonical if variants.include?(key)
      end

      nil
    end

    private

    def canonicalize(str)
      str.to_s.downcase
         .tr(' ', '_')
         .gsub(/[^a-z0-9_\-]/, '')
         .gsub('-', '_')
    end
  end
end
