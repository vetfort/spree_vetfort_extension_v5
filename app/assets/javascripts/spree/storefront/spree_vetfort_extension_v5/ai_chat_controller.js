import { Controller } from "@hotwired/stimulus";

import { TOPICS } from "./constants";
import { ScrollManager } from "./services/scroll_manager";
import { chatApi } from "./services/api";
export default class extends Controller {
  static targets = [
    "messages",
    "scroll",
    "input",
    "form",
    "sendButton",
    "toggleButton",
    "dialog",
    "heroWindow",
    "openChatButton",
    "typingIndicator",
  ];

  connect() {
    this.openInitialComponent();
    this.subscribeToPubSub();

    this.scrollManager = new ScrollManager({
      scrollContainer: this.scrollTarget,
      messagesContainer: this.messagesTarget
    });
  }

  subscribeToPubSub() {
    const { PubSub } = window.VetfortDeps || {};
    if (!PubSub) { console.warn("PubSub not loaded"); }
    this.pubsub = PubSub;

    this.closeHeroCtaSubscription = this.pubsub.subscribe(TOPICS.CLOSE_HERO_CTA, () => this.closeHeroCta());
    this.suggestionsClickSubscription = this.pubsub.subscribe(TOPICS.SUGGESTIONS_CLICK, (_, data) => this.suggestionsClick(data));
    this.heroInputClickSubscription = this.pubsub.subscribe(TOPICS.HERO_INPUT_CLICK, () => this.heroInputClick());

    this.beforeStreamRenderSubscription = this.beforeStreamRender.bind(this);
    document.addEventListener("turbo:before-stream-render", this.beforeStreamRenderSubscription);
  }

  unsubscribeFromPubSub() {
    this.pubsub.unsubscribe(this.closeHeroCtaSubscription);
    this.pubsub.unsubscribe(this.suggestionsClickSubscription);
    this.pubsub.unsubscribe(this.heroInputClickSubscription);

    document.removeEventListener("turbo:before-stream-render", this.beforeStreamRenderSubscription);
  }

  disconnect() {
    this.scrollManager?.disconnect();
    this.unsubscribeFromPubSub();
  }

  beforeStreamRender(event) {
    const el = event.target;

    if (el?.tagName === 'TURBO-STREAM' && el.getAttribute('target') === this.messagesTarget.id) {
      this.typingIndicatorTarget.classList.add('hidden');
    }
  }

  suggestionsClick(data) {
    this.toggleDialog();
    this.appendUserMessage(data);
    this.beginRequest(data);
    this.closeHeroCta();
    this.setBusy(true);
    this.inputTarget.value = "";
  }

  heroInputClick() {
    this.toggleDialog();
    this.closeHeroCta();
  }

  closeHeroCta() {
    this.openChatButtonTarget.classList.remove("hidden");
    this.heroWindowTarget.classList.add("hidden");
    sessionStorage.setItem('close_for_this_session', 'true');
  }

  openInitialComponent() {
    const dontShowAgain = localStorage.getItem('dont_show_ai_consultant_cta');
    const closeForThisSession = sessionStorage.getItem('close_for_this_session');

    if (closeForThisSession && closeForThisSession === 'true') {
      this.openChatButtonTarget.classList.remove("hidden");
    } else {
      if (dontShowAgain && dontShowAgain === 'true') {
        this.openChatButtonTarget.classList.remove("hidden");
      } else {
        this.heroWindowTarget.classList.remove("hidden");
      }
    }
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
  }

  async beginRequest(message) {
    if (this.abortController) this.abortController.abort();
    this.abortController = new AbortController();
    this.setBusy(true);
    this.typingIndicatorTarget.classList.toggle("hidden", false);

    try {
      const response = await chatApi.sendMessage(message, {
        signal: this.abortController.signal
      });

      if (!response) return;
      if (response.ok) {
        console.log('AI request successful');
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
    if (!isBusy) {
      this.inputTarget.focus();
    }
  }

  toggleDialog() {
    this.dialogTarget.classList.toggle("hidden");
    this.inputTarget.focus();
  }
}
