require 'dry-monads'

module Spree
  module Admin
    module VetfortExtensionV5
      class ProductImportsController < Spree::Admin::BaseController
        include Dry::Monads[:task]

        before_action :set_product_import, only: [
          :edit, :update, :update_common, :manage_columns, :remap_column, :remove_column, :import
        ]

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
          initial_csv_headers = csv_data.headers

          if csv_data.empty?
            flash[:error] = Spree.t('admin.spree_vetfort.import.empty_file')
            redirect_to admin_vetfort_extension_v5_product_imports_path and return
          end

          valid_fields = Spree::VetfortExtensionV5::ProductImport::DEFAULT_FIELDS.map(&:to_s)
          field_mapping = csv_data.headers.filter_map do |header|
            canonical = valid_fields.find { |f| f.downcase == header.to_s.downcase }
            if canonical
              [header, canonical]
            else
              [header, header]
            end
          end.to_h

          import = Spree::VetfortExtensionV5::ProductImport.new(
            user: current_user,
            field_mapping:,
            initial_csv_headers:
          )

          ActiveRecord::Base.transaction do
            import.save!

            csv_data.each do |row|
              raw_data = row.to_h.transform_keys(&:to_s)
              processed_data = Mapper.new(raw_data:, field_mapping:).call

              import.product_import_rows.create!(
                raw_data: raw_data,
                processed_data: processed_data
              )
            end
          end

          redirect_to edit_admin_vetfort_extension_v5_product_import_path(import)
        end


        def edit
          @import = Spree::VetfortExtensionV5::ProductImport.includes(:product_import_rows).find(params[:id])
        end

        def update
        end

        def import
          Task[:io] do
            Operations::ProductImports::Import.new.call(product_import: @import)
          end

          flash[:success] = 'Import started'
          redirect_to edit_admin_vetfort_extension_v5_product_import_path(@import)
        end

        def remap_column
          unless params[:value].presence
            flash[:error] = 'Invalid value'
            redirect_to edit_admin_vetfort_extension_v5_product_import_path(@import) and return
          end

          field_mapping = @import.field_mapping || {}
          field_mapping[params[:field]] = params[:value].presence
          @import.update!(field_mapping: field_mapping)

          @import.product_import_rows.find_each do |row|
            row.update!(
              processed_data: Mapper.new(
                raw_data: row.raw_data,
                field_mapping: @import.field_mapping,
                previous_processed_data: row.processed_data
              ).call
            )
          end

          respond_to do |format|
            format.turbo_stream {
              render turbo_stream: [
                turbo_stream.replace(
                  "product-import-head",
                  view_context.render(
                    ::VetfortExtensionV5::Imports::ImportTableComponent.new(import: @import)
                  )
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
          field_mapping = @import.field_mapping || {}
          new_field_mapping = field_mapping.reject { |_k, v| v == params[:field] }
          @import.update!(field_mapping: new_field_mapping)

          respond_to do |format|
            format.turbo_stream {
              render turbo_stream: [
                turbo_stream.replace(
                  "product-import-head",
                  view_context.render(
                    ::VetfortExtensionV5::Imports::ImportTableComponent.new(import: @import)
                  )
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

        def import_map_common_property_select_options
          scope = Spree::Property
            .pluck(:id, :presentation)
            .map { |id, presentation| { id: id, name: presentation } }

          render json: scope.as_json
        end

        def import_map_common_option_select_options
          scope = Spree::OptionType
            .pluck(:id, :name)
            .map { |id, name| { id: id, name: name } }

          render json: scope.as_json
        end

        private

        def set_product_import
          @import = Spree::VetfortExtensionV5::ProductImport.includes(:product_import_rows).find(params[:id])
        end

        def import_params
          params.permit(:file)
        end

        def common_params
          params.require(:common).permit(taxons: [], properties: [], options: [])
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
