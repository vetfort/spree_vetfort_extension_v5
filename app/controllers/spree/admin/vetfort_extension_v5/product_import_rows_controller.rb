require 'dry-monads'

module Spree
  module Admin
    module VetfortExtensionV5
      class ProductImportRowsController < Spree::Admin::BaseController
        include Dry::Monads[:task]

        before_action :set_product_import, only: [
          :update,
          :import,
          :import_map_row_taxons_select_options,
          :import_map_row_properties_select_options
        ]
        before_action :set_product_import_row, only: [
          :update,
          :import,
          :import_map_row_taxons_select_options,
          :import_map_row_properties_select_options
        ]

        def update
          processed_data = @row.processed_data.merge(row_params)

          @row.update!(processed_data:)

          respond_to do |format|
            format.turbo_stream {
              render turbo_stream: [
                turbo_stream.replace(
                  "edit-row-sidedrawer-#{@row.id}",
                  partial: "spree/admin/vetfort_extension_v5/product_imports/edit_row_sidedrawer_form",
                  locals: { import: @import, row: @row }
                ),
              ]
            }
          end
        end

        def import
          flash_type, message = process_row_import

          @import.product_import_rows.reload

          respond_to do |format|
            format.html do
              flash[flash_type] = message if flash_type && message
              redirect_to edit_admin_vetfort_extension_v5_product_import_path(@import)
            end

            format.turbo_stream do
              flash.now[flash_type] = message if flash_type && message

              render turbo_stream: [
                turbo_stream.replace(
                  "product-import-head",
                  view_context.render(
                    ::VetfortExtensionV5::Imports::ImportTableComponent.new(import: @import)
                  )
                )
              ]
            end
          end
        end

        def import_map_row_taxons_select_options
          common_taxon_ids = @row.common_values['taxons'] || []

          latest_taxon_update = current_store.taxons.maximum(:updated_at)
          cache_key = "taxons_select_options_#{current_store.id}_#{@row.id}_#{common_taxon_ids.join('_')}_#{latest_taxon_update.to_i}"

          scope = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
            current_store.taxons
              .where.not(parent_id: nil)
              .where.not(id: common_taxon_ids)
              .pluck(:id, :pretty_name)
              .map { |id, pretty_name| { id: id, name: pretty_name } }
          end

          render json: scope.as_json
        end

        def import_map_row_properties_select_options
          common_property_ids = @row.common_values['properties'] || []

          latest_property_update = Spree::Property.maximum(:updated_at)
          cache_key = "properties_select_options_#{current_store.id}_#{@row.id}_#{common_property_ids.join('_')}_#{latest_property_update.to_i}"

          scope = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
            Spree::Property
              .where.not(id: common_property_ids)
              .pluck(:id, :presentation)
              .map { |id, presentation| { id: id, name: presentation } }
          end

          render json: scope.as_json
        end

        private

        def set_product_import
          @import = Spree::VetfortExtensionV5::ProductImport.includes(:product_import_rows).find(params[:product_import_id])
        end

        def set_product_import_row
          @row = @import.product_import_rows.find(params[:id])
        end

        def process_row_import
          return [:error, 'Эту строку нельзя импортировать повторно'] unless @row.may_import? || @row.may_process?

          Task[:io] { ProductRowImporter.new.call(row: @row) }

          [:success, 'Импорт запущен в фоне. Мы сообщим, когда будет готово.']
        end

        def generate_error_message(result)
          return result.failure if result.failure.is_a?(String)

          "[#{result.failure.class}] #{result.failure.message}"
        end

        def row_params
          params.require(:product_import_row).permit(
            :sku, :name, :url, :price, :description,
            taxons: [], properties: []
          )
        end
      end
    end
  end
end
