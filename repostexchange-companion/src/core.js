(function attachCore(root, build) {
  const api = build();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.RepostCompanionCore = api;
})(typeof globalThis === "object" ? globalThis : this, function buildCore() {
  const DAILY_TARGET = 20;
  const ROLLING_LIMIT = 10;
  const WINDOW_MS = 12 * 60 * 60 * 1000;
  const MAX_COMMENT_LENGTH = 280;

  const LEADS = [
    "I really liked",
    "What stood out to me was",
    "My favorite detail was",
    "I keep coming back to",
    "The highlight for me was",
    "I enjoyed",
    "A standout moment was",
    "I loved the feel of"
  ];

  const ENDS = [
    ".",
    " — nice work on this one.",
    ". Thanks for sharing it.",
    "; it made the track memorable for me.",
    " — really enjoyed this listen.",
    ". That was a highlight for me.",
    "; it gave this one a character I enjoyed.",
    ". I had a great time listening."
  ];

  function localDateKey(value) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "";
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  function parseCompletion(entry) {
    const value = typeof entry === "number" ? entry : entry && entry.completedAt;
    const timestamp = typeof value === "number" ? value : Date.parse(value);
    return Number.isFinite(timestamp) ? timestamp : null;
  }

  function getProgress(entries, now = Date.now()) {
    const list = Array.isArray(entries) ? entries : [];
    const todayKey = localDateKey(now);
    const completed = list
      .map((entry) => ({ entry, timestamp: parseCompletion(entry) }))
      .filter(({ timestamp }) => timestamp !== null && timestamp <= now);
    const todayCount = completed.filter(({ timestamp }) => localDateKey(timestamp) === todayKey).length;
    const recent = completed
      .filter(({ timestamp }) => now - timestamp < WINDOW_MS)
      .sort((a, b) => a.timestamp - b.timestamp);
    const nextSlotAt = recent.length >= ROLLING_LIMIT
      ? recent[recent.length - ROLLING_LIMIT].timestamp + WINDOW_MS
      : null;

    return {
      todayCount,
      dailyTarget: DAILY_TARGET,
      rollingCount: recent.length,
      rollingLimit: ROLLING_LIMIT,
      nextSlotAt,
      canLog: todayCount < DAILY_TARGET && recent.length < ROLLING_LIMIT
    };
  }

  function hashText(value) {
    let hash = 2166136261;
    for (let index = 0; index < value.length; index += 1) {
      hash ^= value.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  }

  function normalizeComment(value) {
    return String(value || "").toLocaleLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();
  }

  function generateDraft(note, recentDrafts = [], seed = `${Date.now()}`) {
    const detail = String(note || "").trim().replace(/[.!?]+$/u, "");
    if (!detail) return "";
    const used = new Set((Array.isArray(recentDrafts) ? recentDrafts : []).map(normalizeComment));
    const combinationCount = LEADS.length * ENDS.length;
    const start = hashText(`${seed}|${detail}`) % combinationCount;

    for (let offset = 0; offset < combinationCount; offset += 1) {
      const candidateIndex = (start + offset) % combinationCount;
      const lead = LEADS[Math.floor(candidateIndex / ENDS.length)];
      const end = ENDS[candidateIndex % ENDS.length];
      const maxDetailLength = MAX_COMMENT_LENGTH - lead.length - end.length - 1;
      let fittedDetail = detail;
      if (fittedDetail.length > maxDetailLength) {
        const clipped = fittedDetail.slice(0, Math.max(1, maxDetailLength - 1));
        const wordBoundary = clipped.lastIndexOf(" ");
        fittedDetail = `${(wordBoundary > maxDetailLength * 0.65 ? clipped.slice(0, wordBoundary) : clipped).trimEnd()}…`;
      }
      const candidate = `${lead} ${fittedDetail}${end}`;
      if (!used.has(normalizeComment(candidate))) return candidate;
    }

    const lead = LEADS[start % LEADS.length];
    const end = " — another detail I appreciated.";
    const maxDetailLength = MAX_COMMENT_LENGTH - lead.length - end.length - 1;
    const fallbackDetail = detail.length > maxDetailLength
      ? `${detail.slice(0, maxDetailLength - 1).trimEnd()}…`
      : detail;
    return `${lead} ${fallbackDetail}${end}`;
  }

  return Object.freeze({
    DAILY_TARGET,
    MAX_COMMENT_LENGTH,
    ROLLING_LIMIT,
    WINDOW_MS,
    generateDraft,
    getProgress,
    localDateKey,
    normalizeComment,
    parseCompletion
  });
});
