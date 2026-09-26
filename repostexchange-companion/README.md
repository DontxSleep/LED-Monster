# Repost Companion — Local Queue

A small Chrome Manifest V3 extension for keeping a local listening checklist and a record of reposts you complete yourself.

## What it does

- Keeps a queue of track titles and artist names on this device.
- Lets you mark a track listened to, then log the repost after you manually submit it.
- Shows progress toward a 20-repost local calendar-day target and the rolling 10-per-12-hour limit.
- Stores the queue and completion times in `chrome.storage.local`.

Repost Companion never opens or reads RepostExchange or SoundCloud, controls playback, clicks repost buttons, writes comments, or runs in the background. Use it as a checklist beside the site; you make each platform decision and action yourself. The rolling limit reflects the [RepostExchange terms](https://repostexchange.com/terms-of-use); check the terms for updates.

## Install locally

1. Open `chrome://extensions` in Chrome.
2. Turn on **Developer mode**.
3. Choose **Load unpacked** and select this `repostexchange-companion` folder.
4. Pin **Repost Companion** to the toolbar.

## Use

Add a track and artist to your queue. Listen on RepostExchange yourself, then mark it listened. If you choose to repost it, submit the repost on RepostExchange yourself and only then select **I reposted it** in the extension. The local queue and count will update.

Run the logic tests with `node --test tests/core.test.cjs`. Build the Chrome Web Store ZIP with `./scripts/package.sh`.

See `store-listing.md` for the proposed listing and privacy disclosures.
