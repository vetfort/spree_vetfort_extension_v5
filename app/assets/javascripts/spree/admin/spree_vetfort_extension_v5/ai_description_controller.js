import { Controller } from "@hotwired/stimulus"
import { put } from "@rails/request.js"
// import { PubSub } from "pubsub-js"


export default class extends Controller {
  static targets = ['generateButton', 'descriptionInput']

  static values = {
    path: String
  }

  connect() {
    this.pubsub = window.VetfortDeps.PubSub;
    const { PubSub } = window.VetfortDeps || {};
    if (!PubSub) { console.warn("PubSub not loaded"); return; }

    this.pubsub = PubSub;
  }

  generate(e) {
    e.preventDefault();

    this.generateButtonTarget.disabled = true;

    put(this.pathValue).then((fetchResponse) => {
      if (fetchResponse.ok) {
        fetchResponse.response.json().then((data) => {
          const { description } = data

          this.pubsub.publish('descriptionGenerated')
        });
      }
    }).catch((error) => {
      console.error(error);
    }).finally(() => {
      this.generateButtonTarget.disabled = false;
    });
  }
}
