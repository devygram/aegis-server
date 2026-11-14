# AGENTS.md — Aegis Server: project summary & history

Summary of what Aegis Server is, how it was built, and everything decided during development (Nov 2026). For any future contributor or AI agent picking this up.

## What the app is

**Aegis Server** — a tiny macOS menu bar app (Swift/SwiftUI) that keeps a Mac awake even with the **lid closed**, so it can run servers, downloads, or long jobs overnight.

- Lives in the menu bar (🛡 icon), no Dock icon, no main window — a `MenuBarExtra` with `.window` style.
- No network connections of its own, except: a quiet update check at launch, and a download only when the user clicks **Update Now**.
- Bundle id: `com.dheddimak.aegisserver`, team `K2ZM94BHS2`.
- Repo: https://github.com/devygram/aegis-server

## What it does

| Feature | Mechanism |
|---|---|
| Keep awake (lid closed) | `pmset -a disablesleep 1` (persistent system setting — covers lid open too) |
| Keep awake (lid open) | `caffeinate -i` background process (lighter; only prevents idle sleep) |
| Wi-Fi watchdog | `pmset networkoversleep/tcpkeepalive/powernap 1` + polling every 6s; if Wi-Fi drops (and the user didn't turn it off), power-cycles the radio via `networksetup` (20s cooldown) |
| Battery warning | Warns when lid-closed mode is on while on battery |
| Start at Login | `SMAppService` |

Key behaviors:

- The two awake modes are **mutually exclusive** (lid-closed already does the lid-open job).
- Password asked **only once**: the app registers a sudoers rule `/etc/sudoers.d/aegis-server` (NOPASSWD for `pmset` and `networksetup`) via the standard macOS admin prompt. The app never sees or stores the password.
- Switches always show the **real system state**, read back from `pmset -g`.
- **Quitting the app releases everything it set** — quit-cleanup checks the *live* `pmset -g` state, not remembered state, so settings can never outlive the app (fixed in v1.2.2 after a real bug).
- Update restarts **preserve** the user's settings (skips cleanup via an `updating` UserDefaults flag, cleared on next launch).

## Updates

- The app checks GitHub (`api.github.com/repos/devygram/aegis-server/releases/latest`) ~3s after launch, silently.
- If a newer release exists: button turns **green "Update Now"** → one click downloads the DMG, mounts it, swaps the app in /Applications (with rollback on failure), relaunches. No browser, no drag-and-drop.
- Version comparison is numeric on `vX.Y[.Z]` tags.

## Source layout

All in `Aegis Server/Aegis Server/Source/` (synchronized folder group — no pbxproj file registration needed):

- `SystemController.swift` — everything shell-related: pmset toggles, watchdog, sudoers setup, caffeinate, update check/install, quit-cleanup.
- `ContentView.swift` — the compact menu bar UI (toggles, status, update row).
- `AegisServerApp.swift` — app entry, `MenuBarExtra`, `AppDelegate.cleanupOnQuit`.
- `project.pbxproj` — **classic format** (converted from Xcode-27 JSON deliberately: CI's Xcode 26.6 can't read the new format). `MARKETING_VERSION` lives here.

## Build & release

Local: open in Xcode and ⌘R, or `xcodebuild -project "Aegis Server.xcodeproj" -scheme "Aegis Server" -configuration Release build`, then copy from DerivedData `Aegis_Server-ccdqoiehudbvphbghnizfeibfavx` to /Applications.

Releasing: bump `MARKETING_VERSION` → commit → `git tag vX.Y && git push origin main vX.Y` → GitHub Actions (`.github/workflows/release.yml`, macos-26 runner) builds and publishes the DMG automatically with `create-dmg` (custom background `assets/dmg-background.png`).

## Version history

| Version | What changed |
|---|---|
| v1.0 | Initial release (was "MimiServer", renamed to Aegis Server) |
| v1.1 | Wi-Fi watchdog |
| v1.2 | Battery warning, Start at Login, mutual-exclusion of awake modes |
| v1.2.1 | Quit releases all settings (first fix) |
| v1.2.2 | Quit-cleanup checks **live** pmset state — leftover settings from older versions get released too |
| v1.3 | Green "Update Now" button when a new release exists |
| v1.4 | **One-click self-update** (download → install → relaunch, settings preserved) |

## Decisions made (and why)

- **No paid Apple Developer signing** — $99/yr not worth it with no users; README explains right-click → Open for first launch. Revisit when there are real users.
- **No Sparkle** — the hand-rolled updater works; Sparkle is the upgrade path later.
- **Removed** at user request: Docker check, Wi-Fi status display (replaced by the Wi-Fi *watchdog*), dev/build sections from README (it's written for end users only — no terminal commands, no Xcode guides).
- **Kept simple**: no timer feature (parked: "keep awake until 5pm"), no settings window, no Dock icon.

## Known parked ideas

- "Keep awake until <time>" timer
- README screenshot of the app window
- Paid signing / notarization
- Sparkle framework
