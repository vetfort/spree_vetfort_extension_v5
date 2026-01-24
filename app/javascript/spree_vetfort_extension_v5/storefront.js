import { application } from "controllers/application"

import AiChatController from "spree_vetfort_extension_v5/controllers/ai_chat_controller"
import AiChatHeroController from "spree_vetfort_extension_v5/controllers/ai_chat/hero_controller"
import AiChatMessageHistoryController from "spree_vetfort_extension_v5/controllers/ai_chat/message_history_controller"
import AiChatFormController from "spree_vetfort_extension_v5/controllers/ai_chat/form_controller"

export function boot() {
  application.register("ai-chat", AiChatController)
  application.register("ai-chat--hero", AiChatHeroController)
  application.register("ai-chat--message-history", AiChatMessageHistoryController)
  application.register("ai-chat--form", AiChatFormController)
}
