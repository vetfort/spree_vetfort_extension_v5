// ai-chat--hero
import { Controller } from "@hotwired/stimulus";

import { TOPICS } from "../constants";

export default class extends Controller {
  connect() {
    const { PubSub } = window.VetfortDeps || {};
    if (!PubSub) { console.warn("PubSub not loaded"); }

    this.pubsub = PubSub;
  }

  close() {
    this.pubsub.publish(TOPICS.CLOSE_HERO_CTA);
  }

  dontShowAiConsultantCta(e) {
    localStorage.setItem('dont_show_ai_consultant_cta', e.target.checked);
  }

  suggestionsClick(e) {
    const suggestionValue = e.target.dataset.suggestionValue;
    this.pubsub.publish(TOPICS.SUGGESTIONS_CLICK, suggestionValue);
  }

  heroInputClick(_e) {
    this.pubsub.publish(TOPICS.HERO_INPUT_CLICK);
  }
}
