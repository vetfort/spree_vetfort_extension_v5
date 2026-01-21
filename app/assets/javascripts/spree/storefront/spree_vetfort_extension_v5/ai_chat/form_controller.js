// ai-chat--form

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "input",
    "form",
    "sendButton",
    "path"
  ];

  connect() {
    if (this.hasPathTarget) {
      this.pathTarget.value = window.location.pathname + window.location.search;
    }

    const { PubSub } = window.VetfortDeps || {};
    if (!PubSub) { console.warn("PubSub not loaded"); }
    this.pubsub = PubSub;

    this.keydownHandler = this.keydownHandler.bind(this);

    this.inputTarget.addEventListener("keydown", this.keydownHandler);
  }

  disconnect() {
    if (this.keydownHandler && this.hasInputTarget) {
      this.inputTarget.removeEventListener("keydown", this.keydownHandler);
    }
  }

  keydownHandler(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      this.formTarget.requestSubmit();
    }
  }

  submit(event) {
    const { TOPICS } = window.VetfortDeps.Constants || {};
    
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
