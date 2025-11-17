// ai-chat--message-history

import { Controller } from "@hotwired/stimulus";

import { ScrollManager } from "../services/scroll_manager";
import { TOPICS } from "../constants";
import { chatApi } from "../services/api";

export default class extends Controller {
  static targets = [
    "placeholder",
    "messages",
    "scroll",
    "typingIndicator",
    "botMessage",
    "customerMessage",
  ];

  connect() {
    const hasTargets = this.hasScrollTarget && this.hasMessagesTarget;

    if (hasTargets) {
      this.scrollManager = new ScrollManager({
        scrollContainer: this.scrollTarget,
        messagesContainer: this.messagesTarget
      });
      this.scrollManager.scrollToBottom();
    }

    this.beforeStreamRenderHandler = this.beforeStreamRender.bind(this);
    document.addEventListener("turbo:before-stream-render", this.beforeStreamRenderHandler);

    const { PubSub } = window.VetfortDeps || {};
    if (!PubSub) { console.warn("PubSub not loaded"); }
    this.pubsub = PubSub;

    if (this.pubsub) {
      this.messageAppendSubscription = this.pubsub.subscribe(TOPICS.MESSAGE_APPEND, (_, data) => this.appendUserMessage(data.text));
      this.beginRequestSubscription = this.pubsub.subscribe(TOPICS.BEGIN_REQUEST, () => this.beginRequestHandler());
    }

    this.visibilityObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.scrollManager?.scrollToBottom();
        }
      });
    });

    this.visibilityObserver.observe(this.element);
  }

  placeholderTargetConnected() {
    this.getCurrentConversation();
  }

  botMessageTargetConnected() {
    this.scrollManager?.scrollToBottom();
  }

  customerMessageTargetConnected() {
    this.scrollManager?.scrollToBottom();
  }

  disconnect() {
    this.scrollManager?.disconnect();
    this.pubsub?.unsubscribe?.(this.messageAppendSubscription);
    this.pubsub?.unsubscribe?.(this.beginRequestSubscription);
    document.removeEventListener("turbo:before-stream-render", this.beforeStreamRenderHandler);
    this.visibilityObserver.disconnect();
  }

  getCurrentConversation() {
    chatApi.getActiveConversation().then(response => {
      if (!response) return;
      if (response.ok) {
        return;
      }
    }).catch(err => {
      console.error('Error getting current conversation', err);
    });
  }

  appendUserMessage(text) {
    const tpl = document.getElementById("ai-chat-message-user");
    if (!tpl) {
      console.error("User message template not found");
      return;
    }

    const node = tpl.content.firstElementChild.cloneNode(true);
    const contentEl = node.querySelector('[data-ai-chat-content]');
    const ts = node.querySelector('[data-ai-chat-timestamp]');
    if (contentEl) contentEl.textContent = text;
    if (ts) ts.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    this.messagesTarget.appendChild(node);
    this.scrollManager?.scrollToBottom();
  }

  beforeStreamRender(event) {
    const el = event.target;

    if (!this.hasMessagesTarget || !this.hasTypingIndicatorTarget) return;
    if (el?.tagName === 'TURBO-STREAM' && el.getAttribute('target') === this.messagesTarget.id) {
      this.typingIndicatorTarget.classList.add('hidden');
    }
  }

  beginRequestHandler() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.remove("hidden");
    }
    this.scrollManager?.scrollToBottom();
  }
}
