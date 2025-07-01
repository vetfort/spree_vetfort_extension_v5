module Spree
  module Admin
    module VetfortExtensionV5
      class ProductImportsController < Spree::Admin::BaseController

        before_action :set_product_import, only: [:edit, :update, :update_common, :manage_columns]

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
          valid_fields = Spree::VetfortExtensionV5::ProductImport::DEFAULT_FIELDS.map(&:to_s)
          field_mapping = csv_data.headers.to_h do |header|
            canonical = valid_fields.find { |f| f.downcase == header.to_s.downcase }
            [header, canonical] if canonical
          end.compact

          initial_csv_headers = csv_data.headers

          if csv_data.empty?
            flash[:error] = Spree.t('admin.spree_vetfort.import.empty_file')
            redirect_to admin_vetfort_extension_v5_product_imports_path and return
          end

          import = Spree::VetfortExtensionV5::ProductImport.new(
            user: current_user,
            field_mapping:,
            initial_csv_headers:
          )

          ActiveRecord::Base.transaction do
            import.save!

            csv_data.each do |row|
              import.product_import_rows.create!(
                raw_data: row.to_h.transform_keys { |key| key.to_s.downcase }.compact
              )
            end
          end

          # import = Spree::VetfortExtensionV5::ProductImport.last
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
                  partial: "spree/admin/vetfort_extension_v5/product_imports/edit_columns_settings_sidedrawer",
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

        def manage_columns
        end

        def remove_column
          @import = Spree::VetfortExtensionV5::ProductImport.includes(:product_import_rows).find(params[:id])

          field_mapping = @import.field_mapping || {}
          new_field_mapping = field_mapping.reject { |_k, v| v == params[:field] }
          @import.update!(field_mapping: new_field_mapping)

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
                  partial: "spree/admin/vetfort_extension_v5/product_imports/edit_columns_settings_sidedrawer",
                  locals: { import: @import }
                )
              ]
            }
          end
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
