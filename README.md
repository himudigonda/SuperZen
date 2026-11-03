<div align="center">

# SuperZen

### Your eyes and focus, looked after automatically.

A native macOS menu bar app that paces your screen time with the **20-20-20 rule**: every 20 minutes, look at something 20 feet (about 6 metres) away for 20 seconds. It stays out of your way the rest of the day.

[![Latest release](https://img.shields.io/github/v/release/himudigonda/SuperZen?style=flat-square&label=download&color=2e7bf6)](https://github.com/himudigonda/SuperZen/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-black?style=flat-square&logo=apple)](#requirements)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue?style=flat-square)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/himudigonda/SuperZen/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/himudigonda/SuperZen/actions/workflows/ci.yml)

**[Download the latest release](https://github.com/himudigonda/SuperZen/releases/latest)** · **[Features](#what-it-does)** · **[Build from source](#build-from-source)**

</div>

---

## Download and install

1. Download `SuperZen-x.y.z.dmg` from the [Releases](https://github.com/himudigonda/SuperZen/releases/latest) page. Each release lists the DMG's SHA-256 checksum.
2. Open the DMG and drag **SuperZen** into **Applications**.
3. Launch it. SuperZen lives in the menu bar and has no Dock icon. A short onboarding sets your focus block length and break style.
4. If the release is not notarized, macOS will refuse to open it the first time. Open **System Settings, Privacy & Security**, choose **Open Anyway**, then confirm. The release notes say which kind of build you have.

## Requirements

* macOS 15 (Sequoia) or later.
* Apple Silicon or Intel.

## Permissions and privacy

SuperZen asks for **no special permissions**.

* **Global shortcuts** use Carbon hotkeys (`RegisterEventHotKey`), so there is no Accessibility prompt.
* **Typing and idle detection** read only how many seconds have passed since your last keyboard or mouse input (`CGEventSource`). No keystrokes are read or stored.
* **The cursor nudge** follows the pointer with standard `NSEvent` mouse-move monitors.
* **App usage in Insights** records the name of the frontmost app from `NSWorkspace` while you focus.

Everything is stored locally with SwiftData. There are no accounts, no analytics service and no network calls.

---

## What it does

### The break cycle

* **20-20-20 by default.** 20 minutes of focus, then a 20 second eye break. Every 4th break is a 5 minute long break to stand up and stretch. All lengths are adjustable, and long breaks can be turned off.
* **A heads-up first.** A small pill follows your cursor for the last 10 seconds before a break, so nothing jumps at you. An optional reminder card can also appear at the top left, centre or right of the screen with Start, Skip and Snooze.
* **Respectful of your flow.** If you are typing when a break is due, SuperZen waits for a pause, for at most 2 minutes.
* **Stepping away counts.** If you are idle for at least 2 minutes (or the break length, if that is longer), it counts as a natural break and the next focus block starts fresh.
* **Sleep, lock and user switching pause the timer**, so a closed lid never turns into fake focus time or an instant break on wake.

### The break screen

A full-screen shield appears on every connected display, above other windows, and rebuilds itself when displays are plugged in or rearranged. Pick a blurred-desktop, gradient or custom-image background. During a break you can add a minute, lock the screen or skip.

Three break styles decide how firm skipping is:

* **Casual:** skip any time.
* **Balanced:** skip after a short wait (half the break by default, never more than a fixed cap).
* **Hardcore:** no skipping.

### Wellness reminders

Short, non-activating pulses for posture, blinking, drinking water and an occasional affirmation. They never take keyboard focus or block clicks, and each has its own interval. They are timed reminders, not trackers.

### Scheduling

* **Focus schedule:** choose working hours and weekdays. Outside them SuperZen sleeps.
* **Quiet hours:** silence wellness reminders during a window, including one that crosses midnight.
* **Day progress:** an optional menu bar bar or label showing how much of your workday is done.

### Insights

A local dashboard built on Swift Charts:

* Focus against your daily goal, breaks taken and skipped, streak, and a 0 to 100 focus quality score.
* A focus trend for today, the week or the month, compared with the same slice of the previous period.
* A timeline of today's focus, idle time and breaks, and a 7 day heatmap of focus by hour.
* A forecast of when you will reach today's goal, based on your workday hours.
* Which apps you used during each focus block.

Stats are split by local hour and day, so midnight and daylight saving changes are counted correctly. Deleting history asks first and reports what was removed.

### Accessibility and languages

* Every control has a VoiceOver label, and break screens and reminders are announced.
* Animations respect **Reduce Motion**, including the cursor nudge, which snaps instead of gliding.
* **Increase Contrast** raises the app's contrast profile.
* Times follow your locale, including 24-hour clocks, and weekdays start on your locale's first day.
* Available in English, Spanish, French and German, with proper plurals.

---

## How it is built

* **Swift 6 and SwiftUI**, with AppKit for the overlay windows.
* **`Packages/SuperZenCore`**: a Foundation-only Swift package that holds every decision: the session engine (a reducer driven by an injected clock with absolute deadlines), schedules, settings validation, insights math, overlay rules and hotkey parsing. It is tested on Linux in CI.
* **The app target** adapts that core to macOS: activity sampling, Carbon hotkeys, overlay windows, SwiftData telemetry with a versioned schema and migration, and the UI design system in `SuperZen/UI/DesignSystem`.
* A 1 second heartbeat feeds the engine. Deadlines are absolute dates, so timers do not drift.

```
Packages/SuperZenCore/   Pure logic and its tests
SuperZen/                macOS app: platform adapters, services, UI
SuperZenTests/           App unit tests (Swift Testing)
SuperZenUITests/         Launch smoke test
scripts/                 DMG, release and their shell tests
docs/RELEASING.md        How to cut a release
```

---

## Build from source

You need Xcode 26 or later. [`just`](https://github.com/casey/just) is optional but handy.

```bash
git clone https://github.com/himudigonda/SuperZen.git
cd SuperZen

just build          # debug build
just test           # app and UI tests through xcodebuild
just lint           # swiftlint --strict
just test-scripts   # shellcheck and the release script tests
```

Or open `SuperZen.xcodeproj` and press Run.

The core package runs on its own, on macOS or Linux:

```bash
swift test --package-path Packages/SuperZenCore
```

Optional tools: `brew install just swiftlint swift-format shellcheck create-dmg`.

## Releasing

`just bump X.Y.Z`, add a `## [X.Y.Z]` section to `CHANGELOG.md`, merge, then `just ship X.Y.Z` on an up to date `main`. That checks the tree, runs lint and tests, builds the DMG and pushes the tag. The Release workflow then builds, optionally signs and notarizes, and publishes the DMG with its checksum. Full details, including the signing secrets, are in [docs/RELEASING.md](docs/RELEASING.md).

---

## License

Apache License 2.0. See [LICENSE](LICENSE).

The bundled Google Sans typeface is licensed under the SIL Open Font License 1.1. See [OFL-GoogleSans.txt](SuperZen/Resources/Fonts/OFL-GoogleSans.txt).

Copyright © 2026 Himansh Mudigonda.

## Inspiration

SuperZen takes inspiration from **LookAway** by Kushagra Agarwal. SuperZen is an independent project and is not affiliated with Mystical Bits, LLC or Kushagra Agarwal.
