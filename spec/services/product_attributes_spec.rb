require 'spec_helper'

RSpec.describe ProductAttributes do
  describe '#to_h' do
    let(:product) { create(:product) }
    let(:product_attributes) { described_class.new(product) }
    let(:brand) { AiSearchable::BrandNormalizer.new.normalize('VetExpert') }

    def tag_product(dimension, value)
      tag_string = AiSearchable::TagFormat.build(dimension, value)
      tag = ActsAsTaggableOn::Tag.find_or_create_by!(name: tag_string)
      product.taggings.find_or_create_by!(tag: tag, context: 'tags')
    end

    def tag_product_with_values(dimension, values)
      Array.wrap(values).each { |value| tag_product(dimension, value) }
    end

    context 'when the product has ai_searchable tags' do
      before do
        tag_product_with_values('species', %w[dog cat])
        tag_product('format', 'Dry ')
        tag_product('diet', 'super premium')
        tag_product_with_values('problem', %w[allergy allergy])
        tag_product('brand', brand)
      end

      it 'returns normalized enum attributes and unique multi-valued dimensions' do
        expect(product_attributes.to_h).to eq(
          species: %i[dog cat],
          format: :dry,
          diet: :super_premium,
          problems: %i[allergy],
          brand: :vetexpert
        )
      end
    end

    context 'when the product is missing some dimensions' do
      before do
        tag_product_with_values('species', %w[dog])
        tag_product('format', 'wet')
      end

      it 'returns nil for absent single-value dimensions and empty arrays for missing multi-value dimensions' do
        expect(product_attributes.to_h).to eq(
          species: %i[dog],
          format: :wet,
          diet: nil,
          problems: [],
          brand: nil
        )
      end
    end
  end
end
