class Mapper
  def initialize(raw_data:, field_mapping:, previous_processed_data: {})
    @raw_data = raw_data
    @field_mapping = field_mapping
    @previous_processed_data = previous_processed_data
  end

  def call
    processed = @previous_processed_data.dup

    @field_mapping.each do |raw_key, mapped_key|
      next if mapped_key.blank?

      value = @raw_data[raw_key]
      processed[mapped_key] ||= process_field(mapped_key, value)
    end

    processed
  end

  private

  def process_field(field, value)
    case field
    when 'taxons'
      return [] if value.blank?

      taxon_names = value.split('|').map(&:strip)
      Spree::Taxon.where(pretty_name: taxon_names).pluck(:id)
    when 'properties'
      return [] if value.blank?
      key_value_pattern = /([^|,]+):\s*([^|,]+)/

      if value.match?(key_value_pattern)
        property_names = value.scan(key_value_pattern).map { |match| match[0].strip }
      else
        delimiter = value.include?(',') ? ',' : '|'
        property_names = value.split(delimiter).map(&:strip)
      end

      Spree::Property.where(filter_param: property_names.uniq).pluck(:id)
    when 'options'
      return [] if value.blank?

      option_names = value.split('|').map(&:strip)
      Spree::OptionValue.where(name: option_names).pluck(:id)
    else
      value
    end
  end
end
