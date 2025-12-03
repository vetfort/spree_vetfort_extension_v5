# frozen_string_literal: true

class AiSearchableTag
  include ActiveModel::Model

  attr_accessor :raw_name, :name, :dimension, :value

  validates :name, presence: true
  validate :validate_ai_format
  validate :validate_value

  def self.ai?(raw_name)
    return false if raw_name.blank?

    raw_name.to_s.start_with?("#{AiSearchable::TagFormat::AI_PREFIX}:")
  end

  def initialize(raw_name:)
    @raw_name = raw_name
    @name = AiSearchable::TagFormat.normalize_value(raw_name)
    parse
  end
  private

  def parse
    parsed = AiSearchable::TagFormat.parse(name)
    return unless parsed

    @dimension = parsed[:dimension]
    @value = parsed[:value]
  end

  def validate_ai_format
    return unless self.class.ai?(raw_name)

    unless dimension && value
      errors.add(:base, "invalid ai_searchable format")
    end
  end

  def validate_value
    return unless dimension && value

    unless AiSearchable::Config.dimensions.include?(dimension.to_s)
      errors.add(:base, "invalid ai_searchable dimension '#{dimension}'")
      return
    end

    return if AiSearchable::Config.allow_any?(dimension)

    allowed = AiSearchable::Config.values_for(dimension)
    return if allowed.include?(value)

    errors.add(:base, "invalid value '#{value}' for dimension '#{dimension}'")
  end
end
