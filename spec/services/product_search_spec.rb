require 'spec_helper'

RSpec.describe ProductSearch do
  subject(:results) { described_class.new(**params).call }

  let(:params) { {} }

  let!(:dog_food) do
    create_product(
      name: 'Dog Food',
      price: 19.99,
      tags: {
        species: %w[dog],
        format: 'dry',
        diet: 'premium',
        problems: %w[allergy],
        brand: 'vetexpert'
      }
    )
  end

  let!(:cat_food) do
    create_product(
      name: 'Cat Food',
      price: 24.99,
      tags: {
        species: %w[cat],
        format: 'wet',
        diet: 'normal',
        problems: %w[hairball],
        brand: 'piper'
      }
    )
  end

  def create_product(name:, price:, tags: {})
    create(:product, name: name, price: price).tap do |product|
      tag_strings = []

      tags.fetch(:species, []).each do |species|
        tag_strings << AiSearchable::TagFormat.build('species', species)
      end

      Array.wrap(tags[:problems]).each do |problem|
        tag_strings << AiSearchable::TagFormat.build('problem', problem)
      end

      %i[format diet brand].each do |dimension|
        value = tags[dimension]
        next if value.blank?

        tag_strings << AiSearchable::TagFormat.build(dimension, value)
      end

      tag_strings.each do |tag_string|
        tag = ActsAsTaggableOn::Tag.find_or_create_by!(name: tag_string)
        product.taggings.find_or_create_by!(tag: tag, context: 'tags')
      end
    end
  end

  describe '#call' do
    it 'returns all products when no filters are provided' do
      expect(results).to contain_exactly(dog_food, cat_food)
    end

    context 'when filtering by species' do
      let(:params) { { species: 'dog' } }

      it 'returns products tagged with the species' do
        expect(results).to contain_exactly(dog_food)
      end
    end

    context 'when filtering by format' do
      let(:params) { { format: 'wet' } }

      it 'returns products tagged with the format' do
        expect(results).to contain_exactly(cat_food)
      end
    end

    context 'when filtering by diet' do
      let(:params) { { diet: 'premium' } }

      it 'returns products tagged with the diet' do
        expect(results).to contain_exactly(dog_food)
      end
    end

    context 'when filtering by problems' do
      let(:params) { { problems: %w[allergy hairball] } }

      it 'returns products tagged with any of the problems' do
        expect(results).to contain_exactly(dog_food, cat_food)
      end
    end

    context 'when filtering by brand' do
      let(:params) { { brand: 'vetexpert' } }

      it 'returns products tagged with the brand' do
        expect(results).to contain_exactly(dog_food)
      end
    end

    context 'when filtering by maximum price' do
      let(:params) { { max_price: 20 } }

      it 'returns products priced below or equal to the maximum' do
        expect(results).to contain_exactly(dog_food)
      end
    end

    context 'when limiting results' do
      let(:params) { { limit: 1, problems: %w[allergy hairball] } }

      it 'applies the limit to the filtered scope' do
        expect(results.size).to eq(1)
      end
    end
  end
end
