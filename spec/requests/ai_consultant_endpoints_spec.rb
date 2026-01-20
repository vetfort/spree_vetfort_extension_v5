# frozen_string_literal: true

require "spec_helper"

RSpec.describe "AI Consultant endpoints", type: :request do
  include ActiveJob::TestHelper

  before(:each) do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  let(:turbo_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }

  describe "POST /ai_conversations" do
    it "accepts JSON {content: ...} and returns 202 JSON" do
      post "/ai_conversations",
           params: { content: "Hi" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
             "ACCEPT" => "application/json"
           }

      expect(response).to have_http_status(:accepted)
    end

    it "accepts Turbo Stream create with nested params ai_conversation[content]" do
      expect {
        post "/ai_conversations",
             params: { ai_conversation: { content: "Hello" } },
             headers: turbo_headers
      }.to have_enqueued_job(AiChatJob)

      expect(response).to have_http_status(:accepted)
    end

    it "sets guest UUID cookie for anonymous users" do
      post "/ai_conversations",
           params: { ai_conversation: { content: "Hello" } },
           headers: turbo_headers

      # Check that cookie jar has the cookie (permanent signed cookies set in response)
      expect(response.cookies["vetfort_guest_uuid"]).to be_present
    end
  end

  describe "POST /ai_conversations/active_conversation" do
    it "returns turbo stream response" do
      post "/ai_conversations/active_conversation", headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end
  end

  describe "POST /ai_conversations/:ai_conversation_id/ai_messages" do
    let!(:conversation) do
      Spree::VetfortExtensionV5::AiConsultantConversation.create!(
        user_identifier: "guest:test",
        last_activity_at: Time.current
      )
    end

    it "accepts message create and enqueues job" do
      expect {
        post "/ai_conversations/#{conversation.id}/ai_messages",
             params: { content: "Need food", ai_conversation_id: conversation.id },
             headers: turbo_headers
      }.to have_enqueued_job(AiChatJob)

      expect(response).to have_http_status(:accepted)

      last_message = conversation.messages.order(:created_at).last
      expect(last_message).not_to be_nil
      expect(last_message.role).to eq("user")
      expect(last_message.content).to eq("Need food")
    end
  end
end
