class Spree::VetfortExtensionV5::ProductImport < ApplicationRecord
  include AASM

  self.table_name = 'product_imports'

  DEFAULT_FIELDS = %w[
    sku
    external_url
    name
    price
    taxons
    properties
    description
  ]

  belongs_to :user, class_name: 'Spree::User'
  has_many :product_import_rows,
           class_name: 'Spree::VetfortExtensionV5::ProductImportRow',
           dependent: :destroy

  # has_one_attached :file

  validates :user_id, presence: true

  # enum status: {
  #   pending: 'pending',
  #   processing: 'processing',
  #   completed: 'completed',
  #   failed: 'failed'
  # }

  aasm column: :status do
    state :pending, initial: true
    state :processing
    state :completed
    state :failed

    event :process do
      transitions from: :pending, to: :processing
      after { update(started_at: Time.current) }
    end

    event :complete do
      transitions from: :processing, to: :completed
      after { update(finished_at: Time.current) }
    end

    event :fail do
      transitions from: :processing, to: :failed
    end

    event :retry do
      transitions from: :failed, to: :processing
    end
  end
end
