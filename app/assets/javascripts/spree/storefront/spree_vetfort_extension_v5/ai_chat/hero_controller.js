// ai-chat--hero
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const { PubSub } = window.VetfortDeps || {};
    if (!PubSub) { console.warn("PubSub not loaded"); }
    const { ChatStateManager } = window.VetfortDeps.ChatStateManager || {};

    this.pubsub = PubSub;
    this.stateManager = new ChatStateManager();
  }

  close() {
    const { TOPICS } = window.VetfortDeps.Constants || {};

    this.pubsub.publish(TOPICS.CLOSE_HERO_CTA);
  }

  dontShowAiConsultantCta(e) {
    if (e.target.checked) {
      this.stateManager.dismissPermanently();
    } else {
      this.stateManager.clearPermanentDismissal();
    }
  }

  suggestionsClick(e) {
    const { TOPICS } = window.VetfortDeps.Constants || {};

    const suggestionValue = e.target.dataset.suggestionValue;
    this.pubsub.publish(TOPICS.SUGGESTIONS_CLICK, suggestionValue);
  }

  heroInputClick(_e) {
    const { TOPICS } = window.VetfortDeps.Constants || {};

    this.pubsub.publish(TOPICS.HERO_INPUT_CLICK);
  }
}
