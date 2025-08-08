class ImportProductRowJob < ApplicationJob
  queue_as :default

  def perform(row:)
    result = ProductRowImporter.new.call(row:)

    if result.success?
      row.import! unless row.imported?
    else
      error_message = generate_error_message(result)
      row.update(error_message:)
      row.fail!
    end
  end

  private

  def generate_error_message(result)
    if result.failure.is_a?(String)
      result.failure
    else
      "[#{result.failure.class}] #{result.failure.message}"
    end
  end
end
