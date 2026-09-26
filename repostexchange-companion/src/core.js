(function attachCore(root, build) {
  const api = build();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.RepostCompanionCore = api;
})(typeof globalThis === "object" ? globalThis : this, function buildCore() {
  const DAILY_TARGET = 20;
  const ROLLING_LIMIT = 10;
  const WINDOW_MS = 12 * 60 * 60 * 1000;

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
      .map((entry) => ({ timestamp: parseCompletion(entry) }))
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

  return Object.freeze({
    DAILY_TARGET,
    ROLLING_LIMIT,
    WINDOW_MS,
    getProgress,
    localDateKey,
    parseCompletion
  });
});
