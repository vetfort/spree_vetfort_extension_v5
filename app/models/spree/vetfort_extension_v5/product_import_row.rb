class Spree::VetfortExtensionV5::ProductImportRow < ApplicationRecord
  include AASM
  include ActionView::RecordIdentifier

  self.table_name = 'product_import_rows'

  belongs_to :product_import
  belongs_to :product, class_name: 'Spree::Product', optional: true

  validates :product_import_id, presence: true

  after_commit :broadcast_actions_cell_update, if: :saved_change_to_status?

  scope :not_imported, -> { where.not(status: :imported) }

  aasm column: :status do
    state :pending, initial: true
    state :processing
    state :skipped
    state :imported
    state :failed

    event :skip do
      transitions from: :pending, to: :skipped
    end

    event :process do
      transitions from: %i[pending failed skipped], to: :processing
    end

    event :import do
      transitions from: %i[failed pending skipped processing], to: :imported
    end

    event :fail do
      transitions from: %i[failed pending skipped processing], to: :failed
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

  private

  def broadcast_actions_cell_update
    Turbo::StreamsChannel.broadcast_update_later_to(
      [product_import, :product_import_rows],
      target: dom_id(self, :actions),
      html: ::ApplicationController.render(
        VetfortExtensionV5::Imports::RowActionsComponent.new(
          import: product_import,
          row: self
        ),
        layout: false
      )
    )
  end
end
