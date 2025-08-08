module Structs
  class ProductAttributesResponseStruct < Dry::Struct
    transform_keys { |key| Types.to_symbol(key) }

    OptionsSchema = Types::Array.of(
      Types::Hash.schema(
        id: Types::Strict::Integer,
        values: Types::Array.of(Types::Strict::Integer)
      ).with_key_transform { |key| Types.to_snake_symbol(key) }
    )

    PropertySchema = Types::Array.of(
      Types::Hash.schema(
        id: Types::Strict::Integer,
        value: Types::Strict::String
      ).with_key_transform { |key| Types.to_snake_symbol(key) }
    )

    LangSectionSchema = Types::Hash.schema(
      name: Types::Strict::String,
      description: Types::Strict::String,
      meta_title: Types::Strict::String,
      meta_description: Types::Strict::String,
      meta_keywords: Types::Strict::String,
      properties: PropertySchema
    ).with_key_transform { |key| Types.to_snake_symbol(key) }

    attribute :ru, LangSectionSchema
    attribute :ro, LangSectionSchema
    attribute :options, OptionsSchema
    attribute :taxons, Types::Array.of(Types::Strict::Integer)
    attribute :sku, Types::String
    attribute :price, Types::Float
    attribute :shipping_category, Types.Instance(Spree::ShippingCategory)
    attribute :external_url, Types::Url
    attribute :tags, Types::Array.of(Types::Strict::String)

    def name(locale = :ru)
      {
        ru: ru[:name],
        ro: ro[:name]
      }[locale]
    end

    def description(locale = :ru)
      {
        ru: ru[:description],
        ro: ro[:description]
      }[locale]
    end

    def meta_title(locale = :ru)
      {
        ru: ru[:meta_title],
        ro: ro[:meta_title]
      }[locale]
    end

    def meta_description(locale = :ru)
      {
        ru: ru[:meta_description],
        ro: ro[:meta_description]
      }[locale]
    end

    def meta_keywords(locale = :ru)
      {
        ru: ru[:meta_keywords],
        ro: ro[:meta_keywords]
      }[locale]
    end

    def properties(locale = :ru)
      {
        ru: ru[:properties],
        ro: ro[:properties]
      }[locale]
    end

    def product_attributes
      {
        name: name,
        price: price,
        sku: sku,
        description: description,
        meta_title: meta_title,
        meta_description: meta_description,
        meta_keywords: meta_keywords,
        shipping_category_id: shipping_category.id,
        external_url: external_url
      }
    end

    def taxons_scope
      Spree::Taxon.where(id: taxons)
    end

    def properties_scope
      all_ids = (properties(:ru) + properties(:ro)).map { |p| p[:id] }.uniq
      props = Spree::Property.where(id: all_ids).index_by(&:id)

      all_ids.each_with_object({}) do |id, acc|
        acc[props[id]] = {
          ru: properties(:ru).find { |p| p[:id] == id }&.dig(:value),
          ro: properties(:ro).find { |p| p[:id] == id }&.dig(:value)
        }
      end
    end

    def options_scope
      option_type_ids = options.map { |o| o[:id] }
      option_types = Spree::OptionType.includes(:option_values).where(id: option_type_ids).index_by(&:id)

      options.each_with_object({}) do |option, acc|
        acc[option_types[option[:id]]] = option[:values].map do |val_id|
          option_types[option[:id]].option_values.find { |ov| ov.id == val_id }
        end.compact
      end
    end

    def tags_scope
      tags
    end
  end
end
