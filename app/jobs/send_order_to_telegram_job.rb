class SendOrderToTelegramJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Spree::Order.find(order_id)
    html  = Bots::TelegramOrderFormatter.html(order)

    Bots::VetfortOpsBot.new.call(message: html)
  rescue => e
    Rails.logger.error("[Telegram] order=#{order_id} #{e.class}: #{e.message}")
  end
end
