require 'spec_helper'

RSpec.describe AiSearchable::TagFormat do
  describe '.build' do
    it 'namespaces the dimension and normalized value' do
      expect(described_class.build('species', 'dog')).to eq('ai_searchable:species:dog')
    end
  end

  describe '.parse' do
    it 'extracts the dimension and value when valid' do
      expect(described_class.parse('ai_searchable:format:wet')).to eq(
        dimension: 'format',
        value: 'wet'
      )
    end

    it 'returns nil when the prefix is missing' do
      expect(described_class.parse('species:dog')).to be_nil
    end

    it 'returns nil for tags without three parts' do
      expect(described_class.parse('ai_searchable:species')).to be_nil
    end
  end

  describe '.normalize_value' do
    it 'returns an empty string when the value is blank' do
      expect(described_class.normalize_value(nil)).to eq('')
      expect(described_class.normalize_value('   ')).to eq('')
    end

    it 'downcases, strips, and replaces spaces with underscores' do
      expect(described_class.normalize_value('  Grain Free Diet ')).to eq('grain_free_diet')
    end
  end
end
