(() => {
  const core = globalThis.RepostCompanionCore;
  const elements = {
    title: document.querySelector("#track-title"),
    artist: document.querySelector("#artist-name"),
    add: document.querySelector("#add-button"),
    dailyCount: document.querySelector("#daily-count"),
    dailyStatus: document.querySelector("#daily-status"),
    dailyFill: document.querySelector("#daily-fill"),
    dailyProgress: document.querySelector("[role='progressbar']"),
    todayLabel: document.querySelector("#today-label"),
    rollingCount: document.querySelector("#rolling-count"),
    rollingMessage: document.querySelector("#rolling-message"),
    rollingDot: document.querySelector("#rolling-dot"),
    limitBanner: document.querySelector("#limit-banner"),
    queueList: document.querySelector("#queue-list"),
    queueCount: document.querySelector("#queue-count"),
    emptyQueue: document.querySelector("#empty-queue"),
    historyList: document.querySelector("#history-list"),
    historyCount: document.querySelector("#history-count"),
    emptyHistory: document.querySelector("#empty-history"),
    toast: document.querySelector("#toast")
  };

  const STORE_KEY = "repostCompanionData";
  let data = { entries: [], queue: [] };
  let toastTimer;

  function todayLabel(date = new Date()) {
    return new Intl.DateTimeFormat(undefined, { weekday: "short", month: "short", day: "numeric" }).format(date);
  }

  function formatTime(timestamp) {
    return new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" }).format(new Date(timestamp));
  }

  function toTimestamp(value) {
    const timestamp = typeof value === "number" ? value : Date.parse(value);
    return Number.isFinite(timestamp) ? timestamp : null;
  }

  function countdown(target, now = Date.now()) {
    const totalMinutes = Math.ceil(Math.max(0, target - now) / 60000);
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    return hours ? `${hours}h ${String(minutes).padStart(2, "0")}m` : `${minutes}m`;
  }

  function toast(message) {
    elements.toast.textContent = message;
    elements.toast.classList.add("is-visible");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => elements.toast.classList.remove("is-visible"), 2200);
  }

  async function save() {
    await chrome.storage.local.set({ [STORE_KEY]: data });
  }

  function updateProgress() {
    const now = Date.now();
    const progress = core.getProgress(data.entries, now);
    elements.todayLabel.textContent = todayLabel(new Date(now));
    elements.dailyCount.textContent = String(progress.todayCount);
    elements.dailyStatus.textContent = progress.todayCount >= progress.dailyTarget ? "daily target reached" : "reposts logged";
    elements.dailyFill.style.width = `${Math.min(100, (progress.todayCount / progress.dailyTarget) * 100)}%`;
    elements.dailyProgress.setAttribute("aria-valuenow", String(Math.min(progress.todayCount, progress.dailyTarget)));
    elements.rollingCount.textContent = `${progress.rollingCount} / ${progress.rollingLimit}`;
    elements.rollingDot.classList.toggle("is-limit", progress.rollingCount >= progress.rollingLimit);

    if (progress.rollingCount >= progress.rollingLimit && progress.nextSlotAt) {
      elements.rollingMessage.textContent = `Next slot in ${countdown(progress.nextSlotAt, now)}`;
      elements.limitBanner.hidden = false;
      elements.limitBanner.textContent = `The 10-repost rolling limit is reached. Your next slot opens around ${formatTime(progress.nextSlotAt)}.`;
    } else if (progress.todayCount >= progress.dailyTarget) {
      elements.rollingMessage.textContent = "12-hour window clear";
      elements.limitBanner.hidden = false;
      elements.limitBanner.textContent = "Daily target reached. Your completed activity is saved locally.";
    } else {
      elements.rollingMessage.textContent = "12-hour window clear";
      elements.limitBanner.hidden = true;
      elements.limitBanner.textContent = "";
    }

    elements.add.disabled = !elements.title.value.trim() || !elements.artist.value.trim();
  }

  function makeTrackCopy(entry) {
    const copy = document.createElement("div");
    copy.className = "queue-copy";
    const title = document.createElement("strong");
    title.textContent = entry.title;
    const detail = document.createElement("span");
    detail.textContent = entry.status === "listened" ? `${entry.artist} · listened` : `${entry.artist} · ready to listen`;
    copy.append(title, detail);
    return copy;
  }

  function makeButton(label, className, onClick, options = {}) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = className;
    button.textContent = label;
    button.disabled = Boolean(options.disabled);
    button.setAttribute("aria-label", options.ariaLabel || label);
    button.addEventListener("click", onClick);
    return button;
  }

  function renderQueue() {
    const sorted = [...data.queue].sort((a, b) => a.addedAt - b.addedAt);
    const progress = core.getProgress(data.entries);
    elements.queueList.replaceChildren();
    elements.queueCount.textContent = `${sorted.length} queued`;
    elements.emptyQueue.hidden = sorted.length > 0;

    for (const entry of sorted) {
      const row = document.createElement("article");
      row.className = "queue-item";
      row.append(makeTrackCopy(entry));
      const actions = document.createElement("div");
      actions.className = "queue-actions";

      if (entry.status === "listened") {
        const canLog = progress.canLog;
        const disabledLabel = progress.todayCount >= progress.dailyTarget ? "Daily goal reached" : "Wait for slot";
        actions.append(makeButton(
          canLog ? "I reposted it" : disabledLabel,
          "button button-log",
          () => completeRepost(entry.id),
          { disabled: !canLog, ariaLabel: canLog ? `Log ${entry.title} after manually reposting it` : disabledLabel }
        ));
      } else {
        actions.append(makeButton("I listened", "button button-step", () => markListened(entry.id)));
      }

      actions.append(makeButton("Remove", "button-remove", () => removeQueuedTrack(entry.id), { ariaLabel: `Remove ${entry.title} from your queue` }));
      row.append(actions);
      elements.queueList.append(row);
    }
  }

  function renderHistory() {
    const sorted = [...data.entries].sort((a, b) => b.completedAt - a.completedAt);
    elements.historyList.replaceChildren();
    elements.historyCount.textContent = `${sorted.length} saved`;
    elements.emptyHistory.hidden = sorted.length > 0;

    for (const entry of sorted.slice(0, 5)) {
      const row = document.createElement("article");
      row.className = "history-item";
      const copy = document.createElement("div");
      copy.className = "history-copy";
      const title = document.createElement("strong");
      title.textContent = entry.title;
      const detail = document.createElement("span");
      detail.textContent = `${entry.artist} · ${formatTime(entry.completedAt)}`;
      copy.append(title, detail);
      const remove = makeButton("Remove", "remove-entry", async () => {
        data.entries = data.entries.filter((item) => item.id !== entry.id);
        await save();
        render();
        toast("Removed from your local log");
      }, { ariaLabel: `Remove ${entry.title} from your local log` });
      row.append(copy, remove);
      elements.historyList.append(row);
    }
  }

  function render() {
    updateProgress();
    renderQueue();
    renderHistory();
  }

  async function addTrack() {
    const title = elements.title.value.trim();
    const artist = elements.artist.value.trim();
    if (!title || !artist) return;
    data.queue.push({ id: crypto.randomUUID(), title, artist, status: "queued", addedAt: Date.now() });
    await save();
    elements.title.value = "";
    elements.artist.value = "";
    render();
    elements.title.focus();
    toast("Added to your local queue");
  }

  async function markListened(id) {
    const entry = data.queue.find((item) => item.id === id);
    if (!entry) return;
    entry.status = "listened";
    entry.listenedAt = Date.now();
    await save();
    render();
    toast("Marked listened — repost it yourself if you choose");
  }

  async function completeRepost(id) {
    const progress = core.getProgress(data.entries);
    const entry = data.queue.find((item) => item.id === id);
    if (!entry || entry.status !== "listened" || !progress.canLog) return;
    const completedAt = Date.now();
    data.entries.push({ id: crypto.randomUUID(), title: entry.title, artist: entry.artist, completedAt });
    data.queue = data.queue.filter((item) => item.id !== id);
    await save();
    render();
    toast("Manual repost added to your local log");
  }

  async function removeQueuedTrack(id) {
    data.queue = data.queue.filter((item) => item.id !== id);
    await save();
    render();
    toast("Removed from your queue");
  }

  elements.title.addEventListener("input", updateProgress);
  elements.artist.addEventListener("input", updateProgress);
  elements.add.addEventListener("click", addTrack);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && (event.target === elements.title || event.target === elements.artist) && !elements.add.disabled) addTrack();
  });

  chrome.storage.local.get(STORE_KEY).then(async (stored) => {
    const saved = stored[STORE_KEY];
    if (saved && typeof saved === "object") {
      data = {
        entries: Array.isArray(saved.entries) ? saved.entries.filter((entry) => entry && toTimestamp(entry.completedAt) !== null).map((entry, index) => ({
          id: typeof entry.id === "string" ? entry.id : `legacy-${index}-${entry.completedAt}`,
          title: String(entry.title || "Untitled track"),
          artist: String(entry.artist || "Unknown artist"),
          completedAt: toTimestamp(entry.completedAt)
        })) : [],
        queue: Array.isArray(saved.queue) ? saved.queue.filter((entry) => entry && typeof entry.title === "string" && typeof entry.artist === "string").map((entry, index) => ({
          id: typeof entry.id === "string" ? entry.id : `queue-${index}-${entry.addedAt || Date.now()}`,
          title: entry.title,
          artist: entry.artist,
          status: entry.status === "listened" ? "listened" : "queued",
          addedAt: Number.isFinite(entry.addedAt) ? entry.addedAt : Date.now(),
          ...(Number.isFinite(entry.listenedAt) ? { listenedAt: entry.listenedAt } : {})
        })) : []
      };
      await save();
    }
    render();
  }).catch(() => {
    render();
    toast("Couldn’t load local history");
  });

  setInterval(render, 30000);
})();
