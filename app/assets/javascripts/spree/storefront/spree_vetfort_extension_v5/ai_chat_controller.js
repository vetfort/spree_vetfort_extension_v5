import { Controller } from "@hotwired/stimulus";

import { TOPICS } from "./constants";
import { ScrollManager } from "./services/scroll_manager";
import { chatApi } from "./services/api";
import { ChatStateManager } from "./services/chat_state_manager";
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
    this.stateManager = new ChatStateManager();
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
    this.stateManager.closeForSession();
    this.openChatButtonTarget.classList.remove("hidden");
    this.heroWindowTarget.classList.add("hidden");
  }

  openInitialComponent() {
    if (this.stateManager.shouldShowHero()) {
      this.heroWindowTarget.classList.remove("hidden");
    } else {
      this.openChatButtonTarget.classList.remove("hidden");
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

  appendUserMessage(text) {
    const tpl = document.getElementById("ai-chat-message-user");
    if (!tpl) {
      console.error("User message template not found");
      return;
    }

    const node = tpl.content.firstElementChild.cloneNode(true);
    const contentEl = node.querySelector('[data-ai-chat-content]');
    const ts = node.querySelector('[data-ai-chat-timestamp]');
    if (contentEl) contentEl.textContent = text;
    if (ts) ts.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    this.messagesTarget.appendChild(node);
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
