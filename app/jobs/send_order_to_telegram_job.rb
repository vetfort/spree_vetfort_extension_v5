class SendOrderToTelegramJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Spree::Order.find(order_id)
    Rails.logger.info("[Telegram] order=#{Order.number} sending to telegram")
    html  = Bots::TelegramOrderFormatter.html(order)
    Rails.logger.info("[Telegram] order=#{Order.number} html=#{html}")
    Bots::VetfortOpsBot.new.call(message: html)
    Rails.logger.info("[Telegram] order=#{Order.number} sent to telegram")
  rescue => e
    Rails.logger.error("[Telegram] order=#{order_id} #{e.class}: #{e.message}")
    raise e
  end
end
