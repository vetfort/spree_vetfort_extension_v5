import { Controller } from "@hotwired/stimulus";

import { TOPICS } from "./constants";
import { chatApi } from "./services/api";
import { ChatStateManager } from "./services/chat_state_manager";
export default class extends Controller {
  static targets = [
    "dialog",
    "dialogBackdrop",
    "heroWindow",
    "openChatButton",
  ];

  connect() {
    this.stateManager = new ChatStateManager();
    this.openInitialComponent();
    this.subscribeToPubSub();
  }

  subscribeToPubSub() {
    const { PubSub } = window.VetfortDeps || {};
    if (!PubSub) { console.warn("PubSub not loaded"); }
    this.pubsub = PubSub;

    this.closeHeroCtaSubscription = this.pubsub.subscribe(TOPICS.CLOSE_HERO_CTA, () => this.closeHeroCta());
    this.suggestionsClickSubscription = this.pubsub.subscribe(TOPICS.SUGGESTIONS_CLICK, (_, data) => this.suggestionsClick(data));
    this.heroInputClickSubscription = this.pubsub.subscribe(TOPICS.HERO_INPUT_CLICK, () => this.heroInputClick());
  }

  unsubscribeFromPubSub() {
    this.pubsub.unsubscribe(this.closeHeroCtaSubscription);
    this.pubsub.unsubscribe(this.suggestionsClickSubscription);
    this.pubsub.unsubscribe(this.heroInputClickSubscription);
  }

  disconnect() {
    this.unsubscribeFromPubSub();
  }

  suggestionsClick(data) {
    this.toggleDialog();
    this.pubsub.publish(TOPICS.MESSAGE_APPEND, { text: data });
    this.beginRequest(data);
    this.closeHeroCta();
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

  async beginRequest(message) {
    if (this.abortController) this.abortController.abort();
    this.abortController = new AbortController();

    this.pubsub.publish(TOPICS.BEGIN_REQUEST);

    try {
      await chatApi.sendMessage(message, {
        signal: this.abortController.signal,
        path: window.location.pathname
      });

      return;
    } catch (err) {
      if (err.name !== "AbortError") console.warn("AI request failed", err);
    }
  }

  stop() {
    if (this.abortController) this.abortController.abort();
  }

  toggleDialog() {
    this.dialogTarget.classList.toggle("hidden");
  }

  toggleMobileDialog() {
    this.dialogTarget.classList.remove("hidden");
    this.dialogBackdropTarget.classList.remove("hidden");
    this.openChatButtonTarget.classList.add("hidden");
  }

  closeMobileDialog() {
    this.dialogTarget.classList.add("hidden");
    this.dialogBackdropTarget.classList.add("hidden");
    this.openChatButtonTarget.classList.remove("hidden");
  }
}
