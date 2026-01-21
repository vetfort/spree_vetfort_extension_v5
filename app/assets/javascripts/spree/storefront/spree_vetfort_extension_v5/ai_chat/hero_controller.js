// ai-chat--hero
import { Controller } from "@hotwired/stimulus";

import { TOPICS } from "../constants.js";
import { ChatStateManager } from "../services/chat_state_manager.js";

export default class extends Controller {
  connect() {
    const { PubSub } = window.VetfortDeps || {};
    if (!PubSub) { console.warn("PubSub not loaded"); }

    this.pubsub = PubSub;
    this.stateManager = new ChatStateManager();
  }

  close() {
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
    const suggestionValue = e.target.dataset.suggestionValue;
    this.pubsub.publish(TOPICS.SUGGESTIONS_CLICK, suggestionValue);
  }

  heroInputClick(_e) {
    this.pubsub.publish(TOPICS.HERO_INPUT_CLICK);
  }
}
