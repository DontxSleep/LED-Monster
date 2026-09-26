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

test("the rolling cap includes the last twelve hours and frees the oldest slot at its exact expiry", () => {
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

test("the daily target is counted for the local calendar day", () => {
  const now = new Date(2026, 8, 26, 23, 30, 0).getTime();
  const first = new Date(2026, 8, 26, 0, 30, 0).getTime();
  const entries = Array.from({ length: 20 }, (_, index) => ({ completedAt: first + index * 70 * 60 * 1000 }));
  const progress = core.getProgress(entries, now);
  assert.equal(progress.todayCount, 20);
  assert.equal(progress.rollingCount, 10);
  assert.equal(progress.canLog, false);
});

test("comment drafts use the supplied note and avoid recent duplicates", () => {
  const note = "the warm bass and loose groove";
  const first = core.generateDraft(note, [], "same-seed");
  const second = core.generateDraft(note, [first], "same-seed");
  assert.match(first, /the warm bass and loose groove/);
  assert.match(second, /the warm bass and loose groove/);
  assert.notEqual(core.normalizeComment(first), core.normalizeComment(second));
});

test("empty notes do not produce a fabricated comment", () => {
  assert.equal(core.generateDraft("  ", [], "seed"), "");
});

test("long notes produce a comment within the service's visible text limit", () => {
  const draft = core.generateDraft("warm bass and groove ".repeat(30), [], "long-note");
  assert.ok(draft.length <= core.MAX_COMMENT_LENGTH);
  assert.ok(draft.includes("…"));
});
