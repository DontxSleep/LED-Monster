# Repost Companion — Manual Tracker

A small Chrome Manifest V3 extension for keeping a local campaign log and drafting comments from your own listening notes.

## What it does

- Tracks completed reposts by your local calendar day and in a rolling 12-hour window.
- Helps you work toward a local target of 20 per day while warning at 10 completed reposts in the last 12 hours.
- Builds varied, editable comment drafts from the listening notes you provide.
- Stores tracks, notes, drafts, and completion times in `chrome.storage.local` on this device.

The extension does not access or modify RepostExchange or SoundCloud pages. It does not play tracks, submit comments, repost, schedule work, or run in the background. Add a track to the log only after you have completed the repost manually. The 10-per-12-hour warning reflects the current RepostExchange terms; check the terms for updates.

## Install locally

1. Open `chrome://extensions` in Chrome.
2. Turn on **Developer mode**.
3. Choose **Load unpacked** and select this `repostexchange-companion` folder.
4. Pin **Repost Companion** to the toolbar for easy access.

## Test and package

Run the local logic tests with `node --test tests/core.test.cjs`. Create the store upload ZIP with `./scripts/package.sh`.

See `store-listing.md` for the proposed listing and privacy disclosures.
