class SendOrderToTelegramJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    return unless ENV["TELEGRAM_BOT_TOKEN"].present? && ENV["TELEGRAM_CHAT_ID"].present?

    order = Spree::Order.find(order_id)
    html  = Bots::TelegramOrderFormatter.html(order)

    Timeout.timeout(5) do
      Bots::VetfortOpsBot.new.call(message: html)
    end
  rescue => e
    Rails.logger.error("[Telegram] order=#{order_id} #{e.class}: #{e.message}")
  end
end
