require 'dry-monads'

module Operations
  module ProductImports
    class Import
      include Dry::Monads[:task]

      def call(product_import:)
        rows = product_import.product_import_rows.not_imported
        tasks = rows.each_slice(slice_size(rows.count, 2)).map do |batch|
          Task[:io] do
            ActiveRecord::Base.connection_pool.with_connection do
              batch.each { |row| process_row(row) }
            end
          end
        end

        tasks.map(&:wait)
      end

      private

      def process_row(row)
        result = ProductRowImporter.new.call(row:)

        if result.success?
          row.import! unless row.imported?
        else
          error_message = generate_error_message(result)
          row.update(error_message:)
          row.fail!
        end
      end

      def slice_size(total_rows, workers_count)
        (total_rows.to_f / workers_count).ceil
      end

      def generate_error_message(result)
        if result.failure.is_a?(String)
          result.failure
        else
          "[#{result.failure.class}] #{result.failure.message}"
        end
      end
    end
  end
end
