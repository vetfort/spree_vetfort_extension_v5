const STORAGE_KEYS = {
  DONT_SHOW_AGAIN: 'dont_show_ai_consultant_cta',
  CLOSED_FOR_SESSION: 'close_for_this_session'
};

class ChatStateManager {
  shouldShowHero() {
    if (this.isClosedForSession()) return false;
    if (this.isDismissedPermanently()) return false;
    return true;
  }

  isClosedForSession() {
    return sessionStorage.getItem(STORAGE_KEYS.CLOSED_FOR_SESSION) === 'true';
  }

  isDismissedPermanently() {
    return localStorage.getItem(STORAGE_KEYS.DONT_SHOW_AGAIN) === 'true';
  }

  closeForSession() {
    sessionStorage.setItem(STORAGE_KEYS.CLOSED_FOR_SESSION, 'true');
  }

  dismissPermanently() {
    localStorage.setItem(STORAGE_KEYS.DONT_SHOW_AGAIN, 'true');
  }

  clearPermanentDismissal() {
    localStorage.removeItem(STORAGE_KEYS.DONT_SHOW_AGAIN);
  }

  reset() {
    sessionStorage.removeItem(STORAGE_KEYS.CLOSED_FOR_SESSION);
    localStorage.removeItem(STORAGE_KEYS.DONT_SHOW_AGAIN);
  }
}

export { ChatStateManager };