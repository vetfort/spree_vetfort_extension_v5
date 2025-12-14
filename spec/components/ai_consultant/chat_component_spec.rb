# frozen_string_literal: true

require "spec_helper"

RSpec.describe VetfortExtensionV5::AiConsultant::ChatComponent do
  class FakeCookieJar
    def initialize
      @signed = {}
    end

    def permanent
      self
    end

    def signed
      @signed
    end
  end

  def build_cookie_jar
    FakeCookieJar.new
  end

  it "assigns a permanent signed guest UUID when current_user is nil" do
    cookies = build_cookie_jar
    expect(cookies.signed[:vetfort_guest_uuid]).to be_nil

    component = described_class.new(current_user: nil, cookies: cookies)

    uuid = cookies.signed[:vetfort_guest_uuid]
    expect(uuid).to be_present

    user_identifier = component.send(:user_identifier)
    expect(user_identifier).to eq("guest:#{uuid}")
  end

  it "does not overwrite guest UUID when already present" do
    cookies = build_cookie_jar
    cookies.permanent.signed[:vetfort_guest_uuid] = "existing-uuid"

    described_class.new(current_user: nil, cookies: cookies)

    expect(cookies.signed[:vetfort_guest_uuid]).to eq("existing-uuid")
  end

  it "does not set guest UUID for authenticated users" do
    cookies = build_cookie_jar
    user = double("User", id: 123)

    described_class.new(current_user: user, cookies: cookies)

    expect(cookies.signed[:vetfort_guest_uuid]).to be_nil
  end
end
