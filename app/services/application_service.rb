require 'dry/monads/all'
require 'rainbow'

class ApplicationService
  include Dry::Monads::Try::Mixin
  include Dry::Monads[:result, :do, :list]

  attr_reader :log_level

  def set_log_level(level:)
    @log_level = level
  end

  def with_warning
    set_log_level(level: :warning)

    self
  end

  def with_info
    set_log_level(level: :info)

    self
  end

  def initialize(*)
    @log_level = :error
  end

  def with_rescue(exception: StandardError, &block)
    result = Try(exception, &block).to_result

    rescue_log(result)

    result
  end

  def rescue_log(result)
    case [log_level, result.failure?]
    in [:error, true]
      Rails.logger.error("\n\n #{Rainbow('--------> [ERROR]').red} Service operation failure in:
          #{self.class.name}, with message: #{result.failure}\n\n")
      Rails.logger.error(Rainbow(result.failure.backtrace.join("\n")).yellow)

    in [:warning, true]
      Rails.logger.warn("#{Rainbow('--------> [WARNING]').yellow} \
        Service: #{self.class.name}, message: #{result.failure}\n")
    in [:info, false]
      Rails.logger.info("#{Rainbow('--------> [INFO]').green}[INFO] \
        Service: #{self.class.name}, message: #{result.success}\n")
    else
      ''
    end
  end
end
