# app/services/conversation_finder.rb

class ConversationFinder < ApplicationService
  INACTIVITY_THRESHOLD = 6.hours

  def initialize(current_user:, guest_uuid:)
    @current_user = current_user
    @guest_uuid = guest_uuid
  end

  def last_active_or_new_conversation
    Spree::VetfortExtensionV5::AiConsultantConversation
      .for_user(user_identifier)
      .with_activity_after(INACTIVITY_THRESHOLD.ago)
      .first_or_create(last_activity_at: Time.current)
  end

  def all_for_user
    Spree::VetfortExtensionV5::AiConsultantConversation
      .for_user(user_identifier)
      .order(last_activity_at: :desc)
      .includes(:messages)
  end

  def new_conversation
    Spree::VetfortExtensionV5::AiConsultantConversation.create!(
      user_identifier: user_identifier,
      last_activity_at: Time.current
    )
  end

  private

  def user_identifier
    @current_user ? "user:#{@current_user.id}" : "guest:#{@guest_uuid}"
  end
end
