# frozen_string_literal: true
# LLMAssistants::Tools::UrlFetch
module LLMAssistants
  module Tools
    class UrlFetch
      extend ::Langchain::ToolDefinition

      attr_reader :llm

      define_function :invoke, description: "Fetches and summarizes content from a given URL and/or user-provided description" do
        property :url, type: "string", required: false, description: "The URL to fetch and summarize"
        property :user_description, type: "string", required: false, description: "Optional user-provided description to enrich or fallback"
      end

      def initialize(llm:)
        @llm = llm
      end

      def invoke(url: nil, user_description: '')
        html_text = ""
        if url.present?
          html_text = fetch_url(url)
          return { error: "Failed to fetch URL" }.to_json unless html_text
        end

        prompt = ::Langchain::Prompt.load_from_path(
          file_path: File.join(__dir__, '..', 'prompts', 'url_summary_prompt.yaml')
        )

        assistant = ::Langchain::Assistant.new(
          llm: llm,
          instructions: prompt.format(url: url || '', content: html_text, user_description: user_description || ''),
          tools: []
        )

        assistant.add_message_and_run!(content: "analyze and summarize")
        assistant.messages.last&.content
      end

      private

      def fetch_url(url, max_redirects: 10)
        response = SsrfFilter.get(
          url,
          max_redirects: max_redirects,
          headers: { 'User-Agent' => 'Vetfort Import Assistant' }
        )
        Rails::HTML::FullSanitizer.new.sanitize(response.body).gsub(/\s+/, ' ').strip
      rescue => e
        Rails.logger.warn("[UrlFetchAssistant] Failed to fetch #{url}: #{e.message}")
        nil
      end

      def llm
        @llm ||= Langchain::LLM::OpenAI.new(
          api_key: ENV["OPENAI_API_KEY"],
          default_options: { model: "gpt-4o-mini", temperature: 0.4 }
        )
      end
    end
  end
end
