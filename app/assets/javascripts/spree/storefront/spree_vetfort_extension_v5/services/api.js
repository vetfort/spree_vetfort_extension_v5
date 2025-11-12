import { post, get } from "@rails/request.js";

export const chatApi = {
  sendMessage(message, { signal } = {}) {
    return post("/ai_consultant", {
      body: JSON.stringify({ message }),
      contentType: "application/json",
      responseKind: "turbo-stream",
      fetch: {
        signal,
        headers: { Accept: "text/vnd.turbo-stream.html, text/html, application/json" }
      }
    });
  },

  getConversations() {
    return get("/ai_consultant", {
      responseKind: "turbo-stream",
      fetch: {
        headers: { Accept: "text/vnd.turbo-stream.html, text/html, application/json" }
      }
    });
  }
};
