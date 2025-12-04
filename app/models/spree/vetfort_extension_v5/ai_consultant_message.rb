class Spree::VetfortExtensionV5::AiConsultantMessage < ApplicationRecord
  self.table_name = 'ai_consultant_messages'

  default_scope { order(created_at: :asc) }

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
  validate :validate_products_structure

  scope :with_products, -> { where.not(products: []) }

  before_validation :normalize_role

  private

  def normalize_role
    self.role = role.to_s if role.present?
  end

  def validate_products_structure
    return if products.blank?

    unless products.is_a?(Array)
      errors.add(:products, "must be an array")
      return
    end

    products.each_with_index do |product, idx|
      unless product.is_a?(Hash)
        errors.add(:products, "item #{idx} must be a hash")
        next
      end

      product_id = product["product_id"] || product[:product_id]
      reason     = product["reason"] || product[:reason]

      if product_id.blank? || reason.blank?
        errors.add(:products, "item #{idx} must have product_id and reason")
      end
    end
  end
end
