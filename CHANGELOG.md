# 🧘‍♂️ SuperZen Changelog

## [1.1.2] - 2026-06-29

### 🐛 Bug Fixes

* **Wellness frequency changes not applied in real-time** — changing posture/blink/water/affirmation frequencies in Settings took effect only after an app restart. `refreshSettings()` now reschedules each next-due time immediately when the frequency changes.
* **Break duration double-applied mid-break** — removing `didSet` on `breakDuration` eliminated a conflict where KVO fired a full-reset, then `refreshSettings()` added a delta on top, causing break duration to become the sum of both.
* **Pause/resume from wellness state lost focus timer** — pausing while a wellness overlay was showing, then resuming, reset `timeRemaining` to the tiny wellness countdown instead of the pre-wellness work timer. `togglePause()` now restores `savedWorkTimeRemaining` for this case.
* **Wellness preview from Settings closed live overlays** — triggering a Settings preview of a wellness type called `closeAll()`, which dismissed any live nudge or break alert. Changed to `closeWellness()` so only fullscreen wellness windows are closed.
* **"Snooze 5m" label hardcoded** — snooze button text was a literal string. Label and action now both derive from a single `snoozeDuration` constant so they can't drift.

### 🧪 Tests

* Added 12 new unit tests (106 total) covering: wellness pause-resume timer restore, `registerDefaults()` idempotency, skip-lock ratio floor and cap clamping, casual/hardcore difficulty skip visibility, typing indicator gating, day-progress disabled path, schedule-vs-manual pause distinction, wellness duration multiplier, and continuous-focus-time reset on break/skip.

---

## [1.1.1] - 2026-06-29

### 🐛 Bug Fixes

* **Settings not respected after launch** — @AppStorage on StateManager did not auto-sync when Settings views wrote to the same UserDefaults keys. Added `refreshSettings()` called on every heartbeat tick to cover all 19 settings.
* **Wellness fires during nudge** — wellness reminders could trigger mid-countdown nudge. Guard now requires `status == .active`.
* **Pause/resume drops break** — pausing during an active break then resuming jumped to `.active` instead of re-entering `.onBreak`. Added `prePauseStatus` to restore the correct state.
* **Break-end sound never played** — `SoundManager.play(.breakEnd)` was never called. Triggered now in `transition(to: .active)` from `.onBreak`.
* **Nudge state showed "Paused" as description** — `AppStatus.description` fell through to `default: "Paused"` for `.nudge`. Fixed with explicit `case .nudge: return "Break soon"`.
* **Interruption count always zero** — `recordIdleTime` checked `seconds >= threshold` where `seconds ≈ 1s`, never matching a 30s threshold. Now accumulates `idleRunSeconds` across heartbeats and counts one interruption per crossing.
* **Hardcore mode skip bypass** — Skip button in `FixedBreakAlertView` was always visible. Now gated behind `difficulty != .hardcore`.
* **Fake debug export in About page** — "Export Logs" wrote hardcoded `{"app":"SuperZen","status":"all_good"}`. Removed entirely.
* **Dead code in MouseTracker** — `targetPosition` was set then immediately overwritten. Removed.
* **Wrong balanced difficulty label** — subtitle said "Wait 5s to skip" (actual cap is 20s). Corrected to "Wait, then skip"; icon changed to `lock.open.fill`.
* **Streak resets to 0 each morning** — `focusGoalStreakDays` started from today (`offset=0`); today's session is still in progress so the streak always appeared broken. Now starts from yesterday (`offset=1`) and has no 30-day cap.
* **Missing `import SwiftData`** — `GeneralSettingsView.swift` used `@Environment(\.modelContext)` without the import.

### 🧪 Tests

* Added 67 new unit tests (91 total) covering: state machine transitions, pause/resume fix, wellness timing, skip-lock logic, TelemetryService interruption accumulation, SchedulePolicy boundary conditions, BreakDifficulty enum, SettingsCatalog validation, DashboardViewModel streak + all insight metrics.
* Fixed 5 pre-existing test failures caused by UserDefaults contamination between serialized tests and stale expected values from before the wellness duration reduction.

### ✨ Improvements

* Wellness overlay durations reduced to 0.75s for posture/blink/water (power-user flash) and 2.0s for affirmations.
* `xcodebuild test` now returns `** TEST SUCCEEDED **` cleanly — shared scheme added to exclude crashing UITests runner (menu-bar-only app has no UI to attach to).

---

## [1.1.0] - 2026-02-26

### ✨ Features
* **Deep Insights Dashboard:** A full-scale analytics suite featuring activity timelines, goal tracking, focus quality scoring, and performance trends.
* **Privacy-First App Usage:** Tracks which applications are used during work blocks to identify focus leaks; data stays 100% on-device.
* **Interface Theming:** Added support for custom Accent Palettes (Ocean, Emerald, Sunset, Violet, Mono) and Contrast Profiles (Soft, Balanced, High).
* **Focus Scheduling:** New automation engine to define "Active Weekdays" and "Active Hours" where focus enforcement is automatically enabled.
* **Quiet Hours:** Define periods where wellness reminders are suppressed to avoid interruptions during late-night or early-morning sessions.
* **Data Retention Policy:** Automated cleanup of historical telemetry data to keep the local database lean.

### 🛠 Improvements
* **Glassmorphism UI:** Complete visual redesign using native macOS thin-materials, vibrant gradients, and 12pt+ rounded corners for a premium look and feel.
* **Hardware-Level Tracking:** Cursor Satellite refresh rate increased to 120Hz with alpha-blending for buttery smooth movement.
* **Kernel Background Activity:** Registered kernels-level activities to prevent macOS App Nap from stalling timers when the dashboard is closed.
* **Resumable Focus Blocks:** Added the ability to resume an interrupted work block after a break instead of forcing a full timer reset.
* **Advanced Skip Logic:** Configurable skip-lock ratios for "Balanced" mode, allowing users to fine-tune how much of a break is mandatory.
* **Smart Wellness Duration:** Added a global multiplier to scale how long wellness overlays (Posture, Blink, Hydration) stay on screen.

---

## [1.0.0] - 2026-02-25

### ✨ Features
* **Unified Heartbeat Engine:** High-precision 0.1s tick for managing breaks and wellness reminders.
* **20-20-20 Rule Enforcement:** Mandatory full-screen breaks to combat Computer Vision Syndrome.
* **Cursor Satellite:** A floating, cursor-following pill that keeps your timer in peripheral vision.
* **Wellness Pulses:** Periodic high-priority physical nudges for Posture, Blinking, and Hydration.
* **Anti-Interruption Logic:** "Don't Show While Typing" engine that detects active work and freezes the deadline until you pause.
* **Global Keyboard Shortcuts:** System-wide controls for starting breaks, skipping, and toggling pause.
* **Sound Manager:** Reactive audio feedback using native macOS system sound banks.
