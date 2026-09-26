(() => {
  const core = globalThis.RepostCompanionCore;
  const elements = {
    title: document.querySelector("#track-title"),
    artist: document.querySelector("#artist-name"),
    note: document.querySelector("#listening-note"),
    generate: document.querySelector("#generate-button"),
    draftPanel: document.querySelector("#draft-panel"),
    draft: document.querySelector("#comment-draft"),
    draftCount: document.querySelector("#draft-char-count"),
    copy: document.querySelector("#copy-button"),
    another: document.querySelector("#another-button"),
    log: document.querySelector("#log-button"),
    dailyCount: document.querySelector("#daily-count"),
    dailyStatus: document.querySelector("#daily-status"),
    dailyFill: document.querySelector("#daily-fill"),
    dailyProgress: document.querySelector("[role='progressbar']"),
    todayLabel: document.querySelector("#today-label"),
    rollingCount: document.querySelector("#rolling-count"),
    rollingMessage: document.querySelector("#rolling-message"),
    rollingDot: document.querySelector("#rolling-dot"),
    limitBanner: document.querySelector("#limit-banner"),
    historyList: document.querySelector("#history-list"),
    historyCount: document.querySelector("#history-count"),
    emptyHistory: document.querySelector("#empty-history"),
    toast: document.querySelector("#toast")
  };

  const STORE_KEY = "repostCompanionData";
  let data = { entries: [], drafts: [] };
  let toastTimer;

  function todayLabel(date = new Date()) {
    return new Intl.DateTimeFormat(undefined, { weekday: "short", month: "short", day: "numeric" }).format(date);
  }

  function formatTime(timestamp) {
    return new Intl.DateTimeFormat(undefined, { hour: "numeric", minute: "2-digit" }).format(new Date(timestamp));
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

    elements.generate.disabled = !elements.title.value.trim() || !elements.artist.value.trim() || !elements.note.value.trim();
    elements.log.disabled = !progress.canLog || !elements.draft.value.trim();
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
      const remove = document.createElement("button");
      remove.className = "remove-entry";
      remove.type = "button";
      remove.textContent = "Remove";
      remove.setAttribute("aria-label", `Remove ${entry.title} from your local log`);
      remove.addEventListener("click", async () => {
        data.entries = data.entries.filter((item) => item.id !== entry.id);
        await save();
        render();
        toast("Removed from your local log");
      });
      row.append(copy, remove);
      elements.historyList.append(row);
    }
  }

  function render() {
    updateProgress();
    renderHistory();
    elements.draftCount.textContent = `${elements.draft.value.length} / 280`;
  }

  async function makeDraft() {
    const note = elements.note.value.trim();
    if (!note) return;
    const draft = core.generateDraft(note, data.drafts, `${Date.now()}|${elements.title.value}|${elements.artist.value}`);
    elements.draft.value = draft;
    elements.draftPanel.hidden = false;
    data.drafts = [...data.drafts, draft].slice(-240);
    await save();
    render();
    elements.draft.focus();
    elements.draft.setSelectionRange(draft.length, draft.length);
  }

  elements.generate.addEventListener("click", makeDraft);
  elements.another.addEventListener("click", makeDraft);
  function invalidateDraft() {
    elements.draft.value = "";
    elements.draftPanel.hidden = true;
    render();
  }

  elements.title.addEventListener("input", invalidateDraft);
  elements.artist.addEventListener("input", invalidateDraft);
  elements.note.addEventListener("input", invalidateDraft);
  elements.draft.addEventListener("input", render);

  elements.copy.addEventListener("click", async () => {
    const value = elements.draft.value.trim();
    if (!value) return;
    try {
      await navigator.clipboard.writeText(value);
      toast("Draft copied");
    } catch {
      toast("Copy unavailable — select the draft and copy it manually");
    }
  });

  elements.log.addEventListener("click", async () => {
    elements.log.disabled = true;
    const progress = core.getProgress(data.entries);
    const title = elements.title.value.trim();
    const artist = elements.artist.value.trim();
    const comment = elements.draft.value.trim();
    if (!progress.canLog || !title || !artist || !comment) {
      render();
      return;
    }

    data.entries.push({
      id: crypto.randomUUID(),
      title,
      artist,
      note: elements.note.value.trim(),
      comment,
      completedAt: Date.now()
    });
    await save();
    elements.title.value = "";
    elements.artist.value = "";
    elements.note.value = "";
    elements.draft.value = "";
    elements.draftPanel.hidden = true;
    render();
    toast("Added to your local log");
  });

  chrome.storage.local.get(STORE_KEY).then((stored) => {
    const saved = stored[STORE_KEY];
    if (saved && typeof saved === "object") {
      data = {
        entries: Array.isArray(saved.entries) ? saved.entries : [],
        drafts: Array.isArray(saved.drafts) ? saved.drafts : []
      };
    }
    render();
  }).catch(() => {
    render();
    toast("Couldn’t load local history");
  });

  setInterval(updateProgress, 30000);
})();
