# frozen_string_literal: true

module VetfortExtensionV5
  module Imports
    class RowActionsComponent < ApplicationComponent
      include ActionView::Helpers::UrlHelper
      attr_reader :import, :row

      STATUS_INDICATORS = {
        'pending' => {
          icon: '⏳',
          label: 'Ожидает импорта',
        },
        'processing' => {
          icon: '⚙️',
          label: 'Импорт в процессе',
        },
        'imported' => {
          icon: '✅',
          label: 'Импортировано',
        },
        'failed' => {
          icon: '❌',
          label: 'Импорт завершился ошибкой',
        },
        'skipped' => {
          icon: '⏭',
          label: 'Строка пропущена',
        }
      }.freeze

      DEFAULT_STATUS_INDICATOR = {
        icon: '❔',
        label: 'Статус неизвестен',
      }.freeze

      def initialize(import:, row:)
        @import = import
        @row = row
      end

      def status_indicator
        indicator = STATUS_INDICATORS.fetch(row.status.to_s) { DEFAULT_STATUS_INDICATOR }
        title = row.failed? ? row.error_message : indicator[:label]
        tag.span(
          indicator[:icon],
          class: "btn btn-sm btn-outline status-indicator",
          title: title,
          role: 'button',
          aria: { disabled: true }
        )
      end

      def run_import_button?
        row.may_import?
      end

      def import_row_path
        helpers.spree.import_admin_vetfort_extension_v5_product_import_product_import_row_path(import, row)
      end

      def show_product_button?
        row.imported? && row.product_id.present?
      end

      def admin_product_path
        helpers.spree.edit_admin_product_path(row.product)
      end
    end
  end
end
