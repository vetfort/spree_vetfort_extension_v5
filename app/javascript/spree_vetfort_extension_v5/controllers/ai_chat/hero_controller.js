// ai-chat--hero
import { Controller } from "@hotwired/stimulus";
import PubSub from 'pubsub-js';
import { ChatStateManager } from "spree_vetfort_extension_v5/services/chat_state_manager";
import { TOPICS } from "spree_vetfort_extension_v5/constants";

export default class extends Controller {
  connect() {
    this.stateManager = new ChatStateManager();
  }

  close() {
    PubSub.publish(TOPICS.CLOSE_HERO_CTA);
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
    PubSub.publish(TOPICS.SUGGESTIONS_CLICK, suggestionValue);
  }

  heroInputClick(_e) {
    PubSub.publish(TOPICS.HERO_INPUT_CLICK);
  }
}
