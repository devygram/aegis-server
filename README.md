# Aegis Server 🛡✨

Keep your Mac awake — even with the **lid closed**.

Aegis Server lives quietly in your menu bar and lets your Mac keep running after you close the lid: perfect for servers, downloads, automations, or long tasks overnight. No Terminal, no settings spelunking — just a switch.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black) ![Swift](https://img.shields.io/badge/SwiftUI-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Why

macOS is designed to sleep when you close the lid — great for battery, terrible when you're hosting something or letting a big job run overnight. Aegis Server flips the switch Apple buried, with a safety net built in.

## What you get

- 🌙 **Keep awake with the lid closed** — close the lid, walk away, the Mac keeps running
- 💻 **Keep awake while you work** — no idle sleep while the lid is open
- 📶 **Wi-Fi watchdog** — if Wi-Fi drops while the lid is closed, the app reconnects it automatically
- 🔋 **Battery-aware** — warns you before lid-closed mode drains your battery
- 🚀 **Start at Login** — set it once and forget it
- ✅ **Honest switches** — the toggles always show the *real* system state, read straight back from macOS

## Install

1. Download **Aegis-Server.dmg** from the [latest release](../../releases).
2. Open it and **drag Aegis Server into Applications**.
3. Launch it — a 🛡 icon appears in your menu bar. Flip the switches, done.

> **First launch only:** if macOS says the app "cannot be opened" because it can't verify the developer, right-click (or Control-click) the app in Applications and choose **Open**, then confirm. It will open normally from then on. This happens because the app isn't signed with a paid developer certificate — it's normal for open-source Mac apps, and the app makes no internet connections of its own.

## Good to know

- The first time you turn on a switch, macOS asks for your **admin password once** — that's the standard macOS prompt; the app never sees or stores your password.
- **Quitting the app releases everything it changed.** App running = Mac stays awake. App quit = back to normal sleep behavior. Nothing is left behind.
- With the lid closed and the Mac awake, it can get warm — plug in for long sessions.

## Privacy

Aegis Server runs entirely on your Mac. It never sends anything anywhere and collects nothing. The only network activity is an occasional, quiet check for new versions — and downloads happen only when you click **Update Now**.

## Updates

The app checks for new versions on its own. When one is available, the button turns green — **Update Now** — and one click installs it and relaunches the app. No downloads, no reinstalling.

## License

[MIT](LICENSE) — free to use, modify and share.
