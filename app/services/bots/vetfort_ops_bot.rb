module Bots
  class VetfortOpsBot
    def call(message:)
      Rails.logger.info("[Telegram] sending message to telegram")
      response = bot.api.send_message(
        chat_id: ENV.fetch("TELEGRAM_CHAT_ID"),
        text: message,
        parse_mode: "HTML"
      )
      Rails.logger.info("[Telegram] response=#{response}")
    end

    private

    def bot
      @bot ||= Telegram::Bot::Client.new(ENV["TELEGRAM_BOT_TOKEN"])
    end
  end
end
