module Bots
  class VetfortOpsBot
    def call(message:)
      bot.api.send_message(
        chat_id: ENV.fetch("TELEGRAM_CHAT_ID"),
        text: message,
        parse_mode: "HTML"
      )
    end

    private

    def bot
      @bot ||= Telegram::Bot::Client.new(ENV["TELEGRAM_BOT_TOKEN"])
    end
  end
end
