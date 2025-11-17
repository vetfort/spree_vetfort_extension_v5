// ai-chat--form

import { Controller } from "@hotwired/stimulus";

import { TOPICS } from "../constants";

export default class extends Controller {
  static targets = [
    "input",
    "form",
    "sendButton",
  ];

  connect() {
    const { PubSub } = window.VetfortDeps || {};
    if (!PubSub) { console.warn("PubSub not loaded"); }
    this.pubsub = PubSub;
  }

  submit(event) {
    const text = this.inputTarget.value.trim();
    if (!text) {
      event.preventDefault();
      return;
    }

    this.pubsub.publish(TOPICS.MESSAGE_APPEND, { text });
    this.pubsub.publish(TOPICS.BEGIN_REQUEST);

    setTimeout(() => {
      this.inputTarget.value = "";
    }, 0);
  }
}
