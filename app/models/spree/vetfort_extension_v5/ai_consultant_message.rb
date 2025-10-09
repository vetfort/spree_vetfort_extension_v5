class Spree::VetfortExtensionV5::AiConsultantMessage < ApplicationRecord
  self.table_name = 'ai_consultant_messages'

  belongs_to :conversation,
             class_name: 'Spree::VetfortExtensionV5::AiConsultantConversation',
             foreign_key: :ai_consultant_conversation_id,
             inverse_of: :messages,
             touch: true

  enum :role, {
    system: 'system',
    user: 'user',
    assistant: 'assistant'
  }, validate: true

  validates :role, presence: true
  validates :content, presence: true

  before_validation :normalize_role

  private

  def normalize_role
    self.role = role.to_s if role.present?
  end
end
