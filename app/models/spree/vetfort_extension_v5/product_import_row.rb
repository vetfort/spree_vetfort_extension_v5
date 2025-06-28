class Spree::VetfortExtensionV5::ProductImportRow < ApplicationRecord
  include AASM

  self.table_name = 'product_import_rows'

  belongs_to :product_import
  belongs_to :product, class_name: 'Spree::Product', optional: true

  validates :product_import_id, presence: true

  # enum :status, {pending: "pending", skipped: "skipped", imported: "imported", failed: "failed"}

  aasm column: :status do
    state :pending, initial: true
    state :skipped
    state :imported
    state :failed

    event :skip do
      transitions from: :pending, to: :skipped
    end

    event :import do
      transitions from: %i[pending skipped], to: :imported
    end

    event :fail do
      transitions from: %i[pending skipped], to: :failed
    end
  end
end
