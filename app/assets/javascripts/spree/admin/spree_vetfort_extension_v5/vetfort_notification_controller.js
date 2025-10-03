import { Controller } from "@hotwired/stimulus"
// import { PubSub } from "pubsub-js"

export default class extends Controller {
  static targets = ['toast']

  static values = {
    delay: {
      type: Number,
      default: 3000,
    },
  }

  initialize() {
    this.hide = this.hide.bind(this)
    this.pubsub = window.VetfortDeps.PubSub;
  }

  connect() {
    this.pubsub.subscribe('descriptionGenerated', () => {
      this.show()
    })
  }

  disconnect() {
    this.pubsub.unsubscribe('descriptionGenerated')
  }

  show() {
    this.toastTarget.classList.remove('vetfort-notification-hidden')
    this.toastTarget.classList.add('flex')

    this.timeout = setTimeout(this.hide, this.delayValue)
  }

  hide() {
    this.toastTarget.classList.add('vetfort-notification-hidden')
    this.toastTarget.classList.remove('flex')
    clearTimeout(this.timeout)
  }
}
