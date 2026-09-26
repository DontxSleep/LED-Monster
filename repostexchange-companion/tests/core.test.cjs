const test = require("node:test");
const assert = require("node:assert/strict");
const core = require("../src/core.js");

const HOUR = 60 * 60 * 1000;

test("daily progress uses the machine's local calendar day", () => {
  const now = new Date(2026, 8, 26, 12, 0, 0).getTime();
  const entries = [
    { completedAt: new Date(2026, 8, 26, 1, 0, 0).getTime() },
    { completedAt: new Date(2026, 8, 25, 23, 59, 0).getTime() },
    { completedAt: now + HOUR }
  ];
  const progress = core.getProgress(entries, now);
  assert.equal(progress.todayCount, 1);
  assert.equal(progress.dailyTarget, 20);
  assert.equal(progress.canLog, true);
});

test("the rolling cap includes the last twelve hours and frees the oldest slot at expiry", () => {
  const now = new Date(2026, 8, 26, 12, 0, 0).getTime();
  const entries = Array.from({ length: 10 }, (_, index) => ({ completedAt: now - (11 - index) * HOUR }));
  const atCap = core.getProgress(entries, now);
  assert.equal(atCap.rollingCount, 10);
  assert.equal(atCap.canLog, false);
  assert.equal(atCap.nextSlotAt, entries[0].completedAt + core.WINDOW_MS);

  const afterExpiry = core.getProgress(entries, atCap.nextSlotAt);
  assert.equal(afterExpiry.rollingCount, 9);
  assert.equal(afterExpiry.canLog, true);
});

test("a completion exactly twelve hours old no longer counts toward the rolling window", () => {
  const now = new Date(2026, 8, 26, 12, 0, 0).getTime();
  const entries = [{ completedAt: now - core.WINDOW_MS }];
  const progress = core.getProgress(entries, now);
  assert.equal(progress.rollingCount, 0);
  assert.equal(progress.canLog, true);
});

test("the daily target is counted for the local calendar day", () => {
  const now = new Date(2026, 8, 26, 23, 30, 0).getTime();
  const first = new Date(2026, 8, 26, 0, 30, 0).getTime();
  const entries = Array.from({ length: 20 }, (_, index) => ({ completedAt: first + index * 70 * 60 * 1000 }));
  const progress = core.getProgress(entries, now);
  assert.equal(progress.todayCount, 20);
  assert.equal(progress.rollingCount, 10);
  assert.equal(progress.canLog, false);
});

test("invalid and future completion timestamps do not affect progress", () => {
  const now = new Date(2026, 8, 26, 12, 0, 0).getTime();
  const progress = core.getProgress([
    { completedAt: "not-a-date" },
    { completedAt: now + HOUR }
  ], now);
  assert.equal(progress.todayCount, 0);
  assert.equal(progress.rollingCount, 0);
});
