// ai-chat--form

import { Controller } from "@hotwired/stimulus";
import PubSub from 'pubsub-js';
import { TOPICS } from "spree_vetfort_extension_v5/constants";

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
    const text = this.inputTarget.value.trim();
    if (!text) {
      event.preventDefault();
      return;
    }

    PubSub.publish(TOPICS.MESSAGE_APPEND, { text });
    PubSub.publish(TOPICS.BEGIN_REQUEST);

    setTimeout(() => {
      this.inputTarget.value = "";
    }, 0);
  }
}
