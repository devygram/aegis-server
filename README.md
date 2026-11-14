# Aegis Server 🛡✨

A tiny macOS menu bar app that turns your Mac into an always-on machine — even with the **lid closed**.

Close the lid, walk away, and your Mac keeps running with Wi-Fi alive: perfect for running servers, downloads, automations, or long tasks overnight.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black) ![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## What it does

| Switch | What it does | Command used |
|---|---|---|
| **Keep Mac Awake (lid open)** | Prevents idle sleep while you're working | `caffeinate -i` (runs in background) |
| **Keep Mac Awake (lid closed)** | The Mac keeps running after you close the lid | `pmset -a disablesleep 1` |
| **Keep Wi-Fi connected (lid closed)** | Stops Wi-Fi from dropping when the lid closes | `pmset -a networkoversleep 1` + `tcpkeepalive 1` + `powernap 1` |

Extra niceties:

- **The two awake modes are mutually exclusive** — the app keeps them from fighting each other.
- **Password is asked only once** — the first time, the app registers a sudoers rule for `pmset`; after that every switch is instant. Your password is never seen or stored by the app (it's the standard macOS admin prompt).
- **Battery warning** — if lid-closed mode is on while running on battery, the app warns you.
- **Start at Login** built in, plus the real state is read back from `pmset -g` so the switches always show the truth.

## Install (no Xcode needed)

1. Grab `Aegis-Server.zip` from the [Releases](../../releases) page and unzip it.
2. Drag **Aegis Server.app** into **Applications**.
3. First launch: if macOS blocks it ("cannot be opened"), run this in Terminal or right-click → **Open**:
   ```bash
   xattr -cr "/Applications/Aegis Server.app"
   ```
   (The app is not notarized yet — this just clears the Gatekeeper flag. The app has no network access to any outside server.)
4. Click the 🛡 icon in the menu bar, flip the switches, done.

## Build it yourself

Requires **macOS 13+** and **Xcode 26+** (the project uses Xcode's new project format).

```bash
git clone https://github.com/YOUR_USERNAME/aegis-server.git
cd aegis-server/Aegis\ Server
xcodebuild -project "Aegis Server.xcodeproj" -scheme "Aegis Server" -configuration Release build
# the app appears in:
# ~/Library/Developer/Xcode/DerivedData/Aegis_Server-*/Build/Products/Release/
```

Or just open `Aegis Server.xcodeproj` in Xcode and press ⌘R.

## ⚠️ Warnings — please read

- **Battery drain:** lid-closed mode keeps the *whole machine* awake. On battery, that will drain it quickly and a closed machine can get warm. The app warns you when you're on battery — plug in for long sessions.
- **Wi-Fi mode is best-effort:** the real mechanism keeping Wi-Fi alive is preventing sleep (`disablesleep`). The Wi-Fi switch adds power-management settings on top; a few Macs/router combos may still drop Wi-Fi.
- **What "disablesleep" means:** your Mac will not sleep even if you *want* it to, until you flip the switch off. It also survives reboots (it's a persistent system setting) — the app re-checks and shows the true state on launch.
- The app changes **system power settings**; no data is destroyed, and turning a switch off restores the previous value.

## Roadmap

- [ ] v1.1: Wi-Fi watchdog — auto-reconnect if Wi-Fi drops while the lid is closed
- [ ] Battery indicator inside the window
- [ ] Optional "keep awake until" timer

## Privacy

The app **never** connects to the internet, never collects anything, and runs everything locally on your Mac.

## License

[MIT](LICENSE) — free to use, modify and share.
