module Spree
  module Admin
    module VetfortExtensionV5
      class ProductImportsController < Spree::Admin::BaseController

        before_action :set_product_import, only: [:edit, :update, :update_common]

        def index
          @imports = Spree::VetfortExtensionV5::ProductImport.all
        end

        def template
        end

        def create
          unless import_params[:file]&.respond_to?(:read)
            flash[:error] = Spree.t('admin.spree_vetfort.import.invalid_file')
            redirect_to admin_vetfort_extension_v5_product_imports_path and return
          end

          unless import_params[:file].content_type == 'text/csv'
            flash[:error] = Spree.t('admin.spree_vetfort.import.invalid_file_type')
            redirect_to admin_vetfort_extension_v5_product_imports_path and return
          end

          csv_data = parse_csv(import_params[:file])
          field_mapping = csv_data.headers.index_with(&:to_s)

          if csv_data.empty?
            flash[:error] = Spree.t('admin.spree_vetfort.import.empty_file')
            redirect_to admin_vetfort_extension_v5_product_imports_path and return
          end

          # ActiveRecord::Base.transaction do
          #   import = Spree::VetfortExtensionV5::ProductImport.create!(user: current_user, field_mapping:)

          #   csv_data.each do |row|
          #     import.product_import_rows.create!(
          #       raw_data: row.to_h.transform_keys(&:to_s).compact
          #     )
          #   end
          # end
          import = Spree::VetfortExtensionV5::ProductImport.last
          redirect_to edit_admin_vetfort_extension_v5_product_import_path(import)
        end

        def edit
          @import = Spree::VetfortExtensionV5::ProductImport.includes(:product_import_rows).find(params[:id])
        end

        def update
        end

        def import
        end

        def remap_column
          @import = Spree::VetfortExtensionV5::ProductImport.includes(:product_import_rows).find(params[:id])

          field_mapping = @import.field_mapping || {}
          field_mapping[params[:field]] = params[:value].presence
          @import.update!(field_mapping: field_mapping)

          respond_to do |format|
            format.turbo_stream {
              render turbo_stream: [
                turbo_stream.replace(
                  "product-import-head",
                  partial: "spree/admin/vetfort_extension_v5/product_imports/import_table",
                  locals: { import: @import }
                ),
                turbo_stream.replace(
                  "product-import-columns-settings",
                  partial: "spree/admin/vetfort_extension_v5/product_imports/columns_settings",
                  locals: { import: @import }
                )
              ]
            }
          end
        end

        def update_common
          @import.update!(common_values: common_params)

          head :ok
        end

        private

        def set_product_import
          @import = Spree::VetfortExtensionV5::ProductImport.includes(:product_import_rows).find(params[:id])
        end

        def import_params
          params.permit(:file)
        end

        def common_params
          params.require(:common).permit(taxons: [])
        end

        def parse_csv(file)
          content = file.read

          content = if content.encoding == Encoding::ASCII_8BIT
                      content.force_encoding('UTF-8')
                    else
                      content.encode('UTF-8')
                    end

          ::CSV.parse(content, headers: true, encoding: 'UTF-8', internal_encoding: 'UTF-8', external_encoding: 'UTF-8')
        rescue ::CSV::MalformedCSVError => e
          Rails.logger.error("CSV Parse Error: #{e.message}")
          []
        end
      end
    end
  end
end
