import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js";

export default class extends Controller {
  static targets = [
    "messages",
    "scroll",
    "input",
    "form",
    "sendButton",
    "stopButton",
    "toggleButton",
    "dialog"
  ];

  connect() {
    this.deferScroll();

    this.messagesObserver = new MutationObserver(() => this.scrollToBottom());
    this.messagesObserver.observe(this.messagesTarget, { childList: true, subtree: false });

    const dialog = document.getElementById("chat-bot-dialog");
    if (dialog) {
      this.dialogObserver = new MutationObserver(() => {
        const isHidden = dialog.classList.contains("hidden");
        if (!isHidden) this.deferScroll();
      });
      this.dialogObserver.observe(dialog, { attributes: true, attributeFilter: ["class"] });
    }
  }

  disconnect() {
    this.messagesObserver?.disconnect();
    this.dialogObserver?.disconnect();
  }

  scrollToBottom() {
    const el = this.scrollTarget || this.messagesTarget;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }

  deferScroll() {
    requestAnimationFrame(() => {
      this.scrollToBottom();
      setTimeout(() => this.scrollToBottom(), 50);
    });
  }

  submit(event) {
    event.preventDefault();
    const text = this.inputTarget.value.trim();
    if (!text) return;
    this.appendUserMessage(text);
    this.inputTarget.value = "";
    this.beginRequest(text);
  }

  appendSystemMessage(text) {
    this.appendMessage(text, "system");
  }

  appendUserMessage(text) {
    const tpl = document.getElementById("ai-chat-message-user");
    if (tpl) {
      const node = tpl.content.firstElementChild.cloneNode(true);
      const contentEl = node.querySelector('[data-ai-chat-content]');
      const ts = node.querySelector('[data-ai-chat-timestamp]');
      if (contentEl) contentEl.textContent = text;
      if (ts) ts.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      this.messagesTarget.appendChild(node);
      this.deferScroll();
      return;
    }
    this.appendMessage(text, "user");
  }

  appendMessage(text, role) {
    const wrapper = document.createElement("div");
    wrapper.className = role === "user" ? "text-right mb-2" : "text-left mb-2";

    const bubble = document.createElement("div");
    bubble.className =
      role === "user"
        ? "inline-block bg-blue-100 text-blue-900 px-3 py-2 rounded-lg"
        : "inline-block bg-gray-100 text-gray-900 px-3 py-2 rounded-lg";

    bubble.textContent = text;
    wrapper.appendChild(bubble);
    this.messagesTarget.appendChild(wrapper);

    this.deferScroll();
  }

  async beginRequest(message) {
    if (this.abortController) this.abortController.abort();
    this.abortController = new AbortController();
    this.setBusy(true);

    try {
      const response = await post(this.formTarget.action || "/ai_consultant", {
        body: JSON.stringify({ message }),
        contentType: "application/json",
        responseKind: "turbo-stream",
        fetch: {
          signal: this.abortController.signal,
          headers: { Accept: "text/vnd.turbo-stream.html, text/html, application/json" }
        }
      });

      if (!response) return; // aborted before fetch started
      if (response.ok) {
        const contentType = response.headers.get("content-type") || "";
        if (contentType.includes("vnd.turbo-stream")) {
          const text = await response.text();
          Turbo.renderStreamMessage(text);
        } else {
          const text = await response.text();
          if (text) this.appendSystemMessage(text);
        }
      }
    } catch (err) {
      if (err.name !== "AbortError") console.warn("AI request failed", err);
    } finally {
      this.setBusy(false);
    }
  }

  stop() {
    if (this.abortController) this.abortController.abort();
    this.setBusy(false);
  }

  setBusy(isBusy) {
    this.inputTarget.disabled = isBusy;
    this.sendButtonTarget.classList.toggle("hidden", isBusy);
    this.stopButtonTarget.classList.toggle("hidden", !isBusy);
    if (!isBusy) {
      this.inputTarget.focus();
    }
  }

  toggleDialog() {
    this.dialogTarget.classList.toggle("hidden");
  }
}
