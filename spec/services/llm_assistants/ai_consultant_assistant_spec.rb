# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LLMAssistants::AiConsultantAssistant do
  describe '.call' do
    let(:messages) do
      [
        { role: 'user', content: 'I need food for my dog' }
      ]
    end

    let(:mock_llm) { instance_double(Langchain::LLM::OpenAI) }
    let(:mock_assistant) { instance_double(Langchain::Assistant) }
    let(:mock_message) do
      double('Message', assistant?: true, content: valid_json_response)
    end

    let(:valid_json_response) do
      {
        text: 'Here are some great options for your dog!',
        products: [
          { product_id: 123, reason: 'High protein formula' },
          { product_id: 456, reason: 'Grain-free option' }
        ]
      }.to_json
    end

    before do
      allow(Langchain::LLM::OpenAI).to receive(:new).and_return(mock_llm)
      allow(Langchain::Prompt).to receive(:load_from_path).and_return(
        double('Prompt', template: 'System instructions...')
      )
      allow(Langchain::Assistant).to receive(:new).and_return(mock_assistant)
      allow(mock_assistant).to receive(:add_message)
      allow(mock_assistant).to receive(:add_message_and_run!)
      allow(mock_assistant).to receive(:messages).and_return([mock_message])
    end

    context 'when LLM returns valid JSON response' do
      it 'parses and returns structured response' do
        result = described_class.call(messages: messages)

        expect(result).to be_an(Array)
        expect(result.first).to include(
          role: 'assistant',
          text: 'Here are some great options for your dog!',
          products: [
            { 'product_id' => 123, 'reason' => 'High protein formula' },
            { 'product_id' => 456, 'reason' => 'Grain-free option' }
          ]
        )
      end

      it 'includes raw JSON in content field' do
        result = described_class.call(messages: messages)

        expect(result.first[:content]).to eq(valid_json_response)
      end
    end

    context 'when LLM returns JSON with empty products array' do
      let(:valid_json_response) do
        {
          text: 'I could not find any products matching your criteria.',
          products: []
        }.to_json
      end

      it 'returns empty products array' do
        result = described_class.call(messages: messages)

        expect(result.first[:products]).to eq([])
        expect(result.first[:text]).to include('could not find')
      end
    end

    context 'when LLM returns invalid JSON' do
      let(:mock_message) do
        double('Message', assistant?: true, content: 'This is not valid JSON {')
      end

      it 'returns fallback response' do
        expect(Langchain.logger).to receive(:warn).with(/Failed to parse JSON response:/)
        expect(Langchain.logger).to receive(:warn).with("Response was: This is not valid JSON {")

        result = described_class.call(messages: messages)

        expect(result.first[:text]).to match(/having trouble/)
        expect(result.first[:products]).to eq([])
      end
    end

    context 'when LLM call raises an error' do
      before do
        allow(Langchain::Assistant).to receive(:new).and_raise(StandardError.new('API error'))
      end

      it 'returns fallback response and logs error' do
        expect(Langchain.logger).to receive(:error).with(/AiConsultantAssistant error/)

        result = described_class.call(messages: messages)

        expect(result.first[:text]).to match(/having trouble/)
        expect(result.first[:products]).to eq([])
      end
    end

    context 'when conversation has multiple messages' do
      let(:messages) do
        [
          { role: 'user', content: 'Hi' },
          { role: 'assistant', content: 'Hello! How can I help you today?' },
          { role: 'user', content: 'I need food for my dog' }
        ]
      end

      it 'adds all prior messages to assistant context' do
        expect(mock_assistant).to receive(:add_message).with(
          role: 'user',
          content: 'Hi'
        )
        expect(mock_assistant).to receive(:add_message).with(
          role: 'assistant',
          content: 'Hello! How can I help you today?'
        )
        expect(mock_assistant).to receive(:add_message_and_run!).with(
          content: 'I need food for my dog'
        )

        described_class.call(messages: messages)
      end
    end

    context 'when custom tools are provided' do
      let(:custom_tool) { double('CustomTool') }
      let(:tools) { [custom_tool] }

      it 'uses provided tools instead of default' do
        expect(Langchain::Assistant).to receive(:new).with(
          hash_including(tools: [custom_tool])
        ).and_return(mock_assistant)

        described_class.call(messages: messages, tools: tools)
      end
    end

    context 'when no tools are provided' do
      it 'uses default ProductsFetch tool' do
        expect(LLMAssistants::Tools::ProductsFetch).to receive(:new).with(
          llm: mock_llm
        ).and_call_original

        described_class.call(messages: messages, tools: [])
      end
    end
  end
end
