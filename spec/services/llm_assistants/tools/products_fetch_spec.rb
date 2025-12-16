# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LLMAssistants::Tools::ProductsFetch do
  let(:mock_llm) do
    double('LLM').tap do |llm|
      allow(llm).to receive(:chat).and_return(
        double('Response', completion: llm_response_json)
      )
    end
  end

  let(:tool) { described_class.new(llm: mock_llm) }

  let!(:dog_food_premium) do
    create_product(
      name: 'Premium Dog Food',
      price: 29.99,
      tags: {
        species: %w[dog],
        format: 'dry',
        diet: 'premium',
        problems: %w[allergy],
        brand: 'vetexpert'
      }
    )
  end

  let!(:cat_food_vet) do
    create_product(
      name: 'Veterinary Cat Food',
      price: 39.99,
      tags: {
        species: %w[cat],
        format: 'wet',
        diet: 'veterinary',
        problems: %w[renal],
        brand: 'royal_canin'
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

  describe '#fetch' do
    context 'when LLM returns valid ai_tags' do
      let(:llm_response_json) do
        {
          ai_tags: {
            species: ['dog'],
            format: ['dry'],
            diet: ['premium']
          }
        }.to_json
      end

      it 'returns products matching the tags' do
        result = tool.fetch(user_intent: 'I need premium dry food for my dog')
        parsed = JSON.parse(result)

        expect(parsed).to be_an(Array)
        expect(parsed.length).to eq(1)
        expect(parsed.first['name']).to eq('Premium Dog Food')
        expect(parsed.first['id']).to eq(dog_food_premium.id)
      end

      it 'includes product price and URL' do
        result = tool.fetch(user_intent: 'I need premium dry food for my dog')
        parsed = JSON.parse(result)

        expect(parsed.first['price']).to be_present
        expect(parsed.first['url']).to include('/products/')
      end
    end

    context 'when LLM returns multiple species' do
      let(:llm_response_json) do
        {
          ai_tags: {
            species: %w[dog cat]
          }
        }.to_json
      end

      it 'returns products for any of the species' do
        result = tool.fetch(user_intent: 'food for dogs and cats')
        parsed = JSON.parse(result)

        expect(parsed.length).to eq(2)
        product_names = parsed.map { |p| p['name'] }
        expect(product_names).to include('Premium Dog Food', 'Veterinary Cat Food')
      end
    end

    context 'when LLM returns no matching tags' do
      let(:llm_response_json) do
        {
          ai_tags: {
            species: ['parrot']
          }
        }.to_json
      end

      it 'falls back to text search' do
        allow(Spree::Product).to receive_message_chain(:active, :ransack, :result, :limit)
          .and_return([])

        result = tool.fetch(user_intent: 'food for my parrot')
        parsed = JSON.parse(result)

        expect(parsed).to be_an(Array)
      end
    end

    context 'when LLM call fails' do
      before do
        allow(mock_llm).to receive(:chat).and_raise(StandardError.new('API error'))
      end

      it 'returns empty array and logs error' do
        expect(Langchain.logger).to receive(:error).with(/ProductsFetch error/)

        result = tool.fetch(user_intent: 'any query')
        parsed = JSON.parse(result)

        expect(parsed).to eq([])
      end
    end

    context 'when LLM returns invalid JSON' do
      let(:llm_response_json) { 'not valid json' }

      it 'returns empty array and logs error' do
        expect(Langchain.logger).to receive(:error).with(/ProductsFetch error/)

        result = tool.fetch(user_intent: 'any query')
        parsed = JSON.parse(result)

        expect(parsed).to eq([])
      end
    end

    context 'when filtering by brand' do
      let(:llm_response_json) do
        {
          ai_tags: {
            brand: 'royal_canin'
          }
        }.to_json
      end

      it 'normalizes and filters by brand' do
        result = tool.fetch(user_intent: 'Royal Canin food')
        parsed = JSON.parse(result)

        expect(parsed.length).to eq(1)
        expect(parsed.first['name']).to eq('Veterinary Cat Food')
      end
    end

    context 'when filtering by max_price' do
      let(:llm_response_json) do
        {
          ai_tags: {
            max_price: '30'
          }
        }.to_json
      end

      it 'filters products by price' do
        result = tool.fetch(user_intent: 'food under $30')
        parsed = JSON.parse(result)

        expect(parsed.length).to eq(1)
        expect(parsed.first['name']).to eq('Premium Dog Food')
      end
    end

    context 'when limit is applied' do
      before do
        # Create more products
        5.times do |i|
          create_product(
            name: "Dog Food #{i}",
            price: 19.99,
            tags: {
              species: %w[dog],
              format: 'dry',
              diet: 'normal'
            }
          )
        end
      end

      let(:llm_response_json) do
        {
          ai_tags: {
            species: ['dog']
          }
        }.to_json
      end

      it 'limits results to 10' do
        result = tool.fetch(user_intent: 'dog food')
        parsed = JSON.parse(result)

        expect(parsed.length).to be <= 10
      end
    end
  end
end
