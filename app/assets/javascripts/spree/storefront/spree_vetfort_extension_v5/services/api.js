import { post, get } from "@rails/request.js";

export const chatApi = {
  sendMessage(message, { signal } = {}) {
    return post("/ai_conversations", {
      body: JSON.stringify({ content: message }),
      contentType: "application/json",
      responseKind: "turbo-stream",
      fetch: {
        signal,
        headers: { Accept: "text/vnd.turbo-stream.html, text/html, application/json" }
      }
    });
  },

  getConversations() {
    return get("/ai_conversations", {
      responseKind: "turbo-stream",
      fetch: {
        headers: { Accept: "text/vnd.turbo-stream.html, text/html, application/json" }
      }
    });
  },

  getActiveConversation() {
    return post("/ai_conversations/active_conversation", {
      responseKind: "turbo-stream",
      fetch: {
        headers: { Accept: "text/vnd.turbo-stream.html, text/html, application/json" }
      }
    });
  }
};
