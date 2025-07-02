module Spree
  module Admin
    module VetfortExtensionV5
      class ProductImportRowsController < Spree::Admin::BaseController
        before_action :set_product_import, only: [:update]
        before_action :set_product_import_row, only: [:update]

        def update
          processed_data = @row.processed_data.merge(row_params)

          @row.update!(processed_data:)

          respond_to do |format|
            format.turbo_stream {
              render turbo_stream: [
                turbo_stream.replace(
                  "edit-row-sidedrawer-#{@row.id}",
                  partial: "spree/admin/vetfort_extension_v5/product_imports/edit_row_sidedrawer",
                  locals: { import: @import, row: @row, col: params[:field] }
                ),
              ]
            }
          end
        end

        private

        def set_product_import
          @import = Spree::VetfortExtensionV5::ProductImport.includes(:product_import_rows).find(params[:product_import_id])
        end

        def set_product_import_row
          @row = @import.product_import_rows.find(params[:id])
        end

        def row_params
          params.require(:product_import_row).permit(taxons: [])
        end


      end
    end
  end
end
