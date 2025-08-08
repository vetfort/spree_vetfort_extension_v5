class Spree::VetfortExtensionV5::ProductImportRow < ApplicationRecord
  include AASM

  self.table_name = 'product_import_rows'

  belongs_to :product_import
  belongs_to :product, class_name: 'Spree::Product', optional: true

  validates :product_import_id, presence: true

  aasm column: :status do
    state :pending, initial: true
    state :skipped
    state :imported
    state :failed

    event :skip do
      transitions from: :pending, to: :skipped
    end

    event :import do
      transitions from: %i[failed pending skipped], to: :imported
    end

    event :fail do
      transitions from: %i[failed pending skipped], to: :failed
    end
  end

  delegate :common_values, to: :product_import

  def taxons_names
    return raw_data['taxons'] unless processed_data['taxons'].present?

    taxons = Spree::Taxon.where(id: processed_data['taxons'])

    return if taxons.blank?

    taxons.pluck(:pretty_name).join(', ')
  end

  def properties_names
    return raw_data['properties'] unless processed_data['properties'].present?

    properties = Spree::Property.where(id: processed_data['properties'])

    return if properties.blank?

    properties.pluck(:presentation).join(', ')
  end
end
