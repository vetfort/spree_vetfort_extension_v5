class Spree::VetfortExtensionV5::AiConsultantConversation < ApplicationRecord
  self.table_name = 'ai_consultant_conversations'

  has_many :messages,
           class_name: 'Spree::VetfortExtensionV5::AiConsultantMessage',
           dependent: :destroy,
           foreign_key: :ai_consultant_conversation_id,
           inverse_of: :conversation

  validates :user_identifier, presence: true, uniqueness: true
  validates :status, presence: true

  scope :recent, -> { order(updated_at: :desc) }

  # Appends a message and updates last_activity_at
  def append_message(role:, content:, id: nil)
    msg = messages.create!(id: id, role: role, content: content)
    touch_last_activity!
    msg
  end

  def register_stream
    Rails.cache.write(streaming_cache_key, true, expires_in: 3.minutes)
  end

  def stop_stream
    Rails.cache.delete(streaming_cache_key)
  end

  def streaming?
    Rails.cache.exist?(streaming_cache_key)
  end

  def generate_message_id
    (Time.current.to_f * 1000).to_i
  end

  def touch_last_activity!
    update_column(:last_activity_at, Time.current)
  end

  private

  def streaming_cache_key
    [:ai_consultant_conversation, to_param, :streaming]
  end
end
