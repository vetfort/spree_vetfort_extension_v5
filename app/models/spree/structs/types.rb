module Structs
  module Types
    include Dry.Types()

    # rubocop:disable Layout/LineLength
    UUID = Types::Strict::String.constrained(format: /((urn:uuid:)?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}|\\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\\}|[0-9a-f]{32})/)
    SHA256 = Types::Strict::String.constrained(min_size: 44, format: /sha256/)
    DateTimeString = Types::Strict::String.constrained(format: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z/)
    # rubocop:enable Layout/LineLength

    def self.to_snake_symbol(string)
      string
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .gsub(/-/, '_')
        .downcase.to_sym
    end
  end
end
