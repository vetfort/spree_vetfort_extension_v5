class ScrollManager {
  constructor({ scrollContainer, messagesContainer }) {
    this.scrollContainer = scrollContainer;
    this.messagesContainer = messagesContainer;
    this.setupObserver();
  }

  setupObserver() {
    this.observer = new MutationObserver(() => this.scrollToBottom());
    this.observer.observe(this.messagesContainer, {
      childList: true,
      subtree: false
    });
  }

  scrollToBottom() {
    const el = this.scrollContainer || this.messagesContainer;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }

  disconnect() {
    this.observer?.disconnect();
  }
}

export { ScrollManager };