require 'dry-monads'
require 'concurrent'

module Operations
  module ProductImports
    class Import
      include Dry::Monads[:task]
      MAX_WORKERS = 5

      def call(product_import:)
        product_import.reload
        product_import.process! if product_import.may_process?

        executor = Concurrent::ThreadPoolExecutor.new(
          min_threads: 0,
          max_threads: MAX_WORKERS,
          max_queue: product_import.product_import_rows.not_imported.count
        )

        begin
          tasks = product_import.product_import_rows.not_imported.map do |row|
            Task[executor] do
              ActiveRecord::Base.connection_pool.with_connection do
                process_row(row)
              end
            end
          end

          tasks.each(&:wait)
        ensure
          executor.shutdown
          executor.wait_for_termination
        end

        finish_import(product_import)
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

      def generate_error_message(result)
        if result.failure.is_a?(String)
          result.failure
        else
          "[#{result.failure.class}] #{result.failure.message}"
        end
      end

      def finish_import(product_import)
        product_import.reload

        rows = product_import.product_import_rows.not_imported

        if rows.where(status: 'failed').exists? || rows.where(status: 'pending').exists?
          product_import.fail! if product_import.may_fail?
        else
          product_import.complete! if product_import.may_complete?
        end
      end
    end
  end
end
