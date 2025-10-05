import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["messages", "input"];

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

    // this.appendSystemMessage("Hi! How can I help?");
  }

  disconnect() {
    this.messagesObserver?.disconnect();
    this.dialogObserver?.disconnect();
  }

  scrollToBottom() {
    const el = this.messagesTarget;
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
  }

  appendSystemMessage(text) {
    this.appendMessage(text, "system");
  }

  appendUserMessage(text) {
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
}
