module Spree
  module Admin
    module VetfortExtensionV5
      class ProductImportRowsController < Spree::Admin::BaseController
        before_action :set_product_import, only: [
          :update,
          :import_map_row_taxons_select_options,
          :import_map_row_properties_select_options
        ]
        before_action :set_product_import_row, only: [
          :update,
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
