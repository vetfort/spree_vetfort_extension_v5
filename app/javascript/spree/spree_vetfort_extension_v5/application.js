import { Application } from "@hotwired/stimulus";
import ProductImportController from "./controllers/product_import_controller";
import AiChatController from "../../ai/controllers/ai_chat_controller";

const application = Application.start();
application.register("product-import", ProductImportController);
application.register("ai-chat", AiChatController);
