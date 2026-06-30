# 🧘‍♂️ SuperZen Changelog

## [1.1.10] - 2026-06-30

### 🐛 Bug Fixes

* **Launch-at-login no longer logs spurious failures.** `setLaunchAtLogin` is now idempotent — it checks the current `SMAppService` status and skips the register/unregister call when already in the desired state. Previously, reconciling on onboarding-finish (or a redundant toggle) could attempt to unregister a service that was never registered, throwing a caught-but-noisy error.

### 📝 Documentation & Project

* **Added an Apache License 2.0 `LICENSE` file** — SuperZen is now properly open-source licensed for public release.
* **Reworked the README into a product landing page** — centered hero with download/license/platform/downloads badges, a screenshots gallery scaffold (ready for captures under `assets/`), clear call-to-action links, and a License section. Combined with the earlier Download / Requirements / Build-from-Source sections, the README now reads as a real front door for the project.

---

## [1.1.9] - 2026-06-30

### 🐛 Bug Fixes

* **Cursor nudge pill could clip off-screen.** The floating "Rest your eyes" pill followed the cursor with a fixed offset and no bounds-checking, so near the right or bottom edge of a display — or across a multi-monitor boundary — it slid partly or fully off-screen. It now clamps to the visible frame of whichever display the cursor is on, so it always stays fully visible.
* **Break/wellness overlay could miss keyboard focus.** `showBreak`/`showWellness` picked the key window via `NSScreen.main`; if that was nil (no focused window), *no* overlay became key and the Skip button received no keyboard events until clicked. Now falls back to the first screen so one window always becomes key.
* **Reminder preview flashed even when reminders were disabled.** Tapping an alert-position card in Appearance always fired a live reminder preview — even with "Reminder alert" toggled off, momentarily flashing a reminder the user had turned off. The preview now only fires when reminders are enabled; the position still updates its selection either way.
* **Onboarding could leave launch-at-login out of sync.** The launch-at-login toggle only registered with `SMAppService` on change, so finishing onboarding without touching it could leave the stored preference and the actual login-item registration divergent. Finishing onboarding now reconciles the service with the stored value.
* **Settings window might not center on open.** `ContentView` located its window by title, which is empty under a hidden title bar, so centering could silently no-op. It now matches the stable window id (`"main"`) first, mirroring the menu-bar open path.
* **Wellness duration multiplier label drift.** The selected pill showed `"%.2g"`-formatted values (e.g. "1x", "2x") that didn't match the picker menu's catalog labels ("1.0x", "2.0x"). The pill now reverse-maps to the catalog label so the two always agree.

### 📝 Documentation

* **README accuracy + pre-release sections.** Corrected the stale "0.1s heartbeat" performance claim (the engine ticks at 1s; the 120Hz figure is the cursor-nudge refresh) and removed a fabricated CPU-percentage figure. Added **Download & Install**, **Requirements** (macOS 26.2+), and **Build from Source** sections, and de-version-coupled the analytics description.

---

## [1.1.8] - 2026-06-30

### 🐛 Bug Fixes

* **Break reminder had a weird rectangular "border" around it.** The reminder card (420×200) draws a soft drop shadow (`radius 24, y 8`), but its host window was only 440×220 — a mere 10pt of margin. The shadow needs ~32pt to fade out, so it was being clipped flat against the window's rectangular edge, producing a hard-edged box around the rounded card. The window's native `hasShadow` then traced that same rectangle, compounding it. Fixed by sizing the window to give the card transparent breathing room for its shadow (matching insets on the view), disabling the redundant native window shadow, and adjusting positioning so the card still sits 40pt from the screen edge. The reminder now floats cleanly with only its soft rounded shadow.

---

## [1.1.7] - 2026-06-30

### 🐛 Bug Fixes

* **Dashboard tests fail after midnight** — `insightsQualityForecastAndWellnessTypeBreakdown` and `insightsGoalProgressClampsAtOne` used `now - N seconds` as session timestamps, which placed them in "yesterday" when run between midnight and ~1 AM. Sessions fell outside the "today" range, so `idleMinutes`, `interruptionsCount`, and `focusGoalProgress` all returned 0. Fixed by anchoring sessions to fixed hours within the current calendar day (`startOfDay + H`) so the assertions are time-of-day-independent.

### 🧪 Tests

* **Added 13 new tests (125 total)** covering areas with zero prior coverage:
  * **Wellness enabled/disabled flags actually gate firing** — `postureEnabled=false` prevents posture from firing even when past due; re-enabling starts a fresh timer (doesn't fire at the original due date).
  * **Wellness fires when enabled and due** — positive-path test exercising the full `checkWellnessReminders` path.
  * **Quiet hours block wellness** — all-day quiet hours prevent posture from firing even when past its due date.
  * **Wellness firing order** — when posture and blink are simultaneously due, posture always fires first (hard-coded check order in `checkWellnessReminders`).
  * **Wellness frequency rescheduling** — shortening `postureFrequency` via UserDefaults + `refreshSettings()` moves `nextPostureDue` forward, so the reminder fires at the new interval (not the original longer one).
  * **Difficulty change via `refreshSettings()`** — switching from Balanced to Casual mid-break immediately makes `canSkip` true.
  * **`balancedSkipLockRatio` change via `refreshSettings()`** — changing the ratio updates the skip threshold; verifies `canSkip` flips from true to false at the same `timeRemaining` after the ratio increases.
  * **`wellnessDurationMultiplier` change via `refreshSettings()`** — dropping multiplier to 0.25× halves the wellness overlay duration on the next transition.
  * **`nudgeLeadTime` change propagates** — setting via UserDefaults + `refreshSettings()` updates the property immediately.
  * **`idleThreshold` change propagates** — same pattern as nudgeLeadTime.
  * **`forceResetFocusAfterBreak=false` via `refreshSettings()`** — verified the timer resumes from elapsed position rather than resetting to full `workDuration` at break end.
  * **Schedule auto-resume resets to full `workDuration`** — after a schedule sleep/wake cycle, `timeRemaining` equals `workDuration` (not some stale pre-sleep value).

* Added `checkWellnessRemindersForTesting(now:)` test hook on `StateManager` to directly drive the wellness-check logic without waiting for the 1-second heartbeat timer.

---

## [1.1.6] - 2026-06-29

### ✨ Features

* **First-run onboarding.** A polished 4-step welcome flow greets new users: what SuperZen does, how it helps (focus blocks, gentle cursor nudges, wellness pulses), a one-tap choice of break intensity (Casual / Balanced / Hardcore) and focus-block length, and a launch-at-login toggle to finish. Built from the app's native glassmorphism design system with full keyboard and VoiceOver support, it gets you set up in about 20 seconds — then hands off to the menu bar.

### 🧪 Tests

* Added a regression test ensuring a fresh install always shows onboarding (112 total).

---

## [1.1.5] - 2026-06-29

### ♿️ Accessibility

* **VoiceOver support across the break experience.** The menu bar item now speaks plain-language status ("SuperZen, focusing, 12 minutes until break" / "on break, 4 minutes 30 seconds remaining" / "paused" / "sleeping on schedule") instead of an icon name and a raw "12:30" glyph string.
* **Spoken countdowns.** The full-screen break timer and the break-reminder alert now read as "2 minutes 30 seconds remaining" rather than "zero-two colon three-zero".
* **Labeled controls.** The reminder's close button, the break overlay's *Add one minute* and *Lock screen* pills, and the skip button all carry clear VoiceOver labels. The skip button announces *why* it's unavailable ("Skip available in 8 seconds" / "Skipping disabled in hardcore mode").
* **Less VoiceOver noise.** The cursor-following nudge pill is now hidden from VoiceOver — it's a passive indicator whose state is already announced by the menu bar, so it no longer chatters as the cursor moves.

### 🧪 Tests

* Added 5 deterministic edge-case tests (111 total) covering focus-schedule sleep/auto-resume (with injected time) and day-progress math, via two new test-only hooks on `StateManager`.

---

## [1.1.4] - 2026-06-29

### 🐛 Bug Fixes

* **App Nap could throttle the timer in the background** — the "disable App Nap" activity token was stored in a plain instance property on the SwiftUI `App` value type, so its lifetime was tied to a transient struct copy and it could deallocate, silently re-enabling App Nap. This let the focus/wellness heartbeat (a RunLoop timer) drift or stall while the menubar app sat in the background. The token is now a process-lifetime `static`, forced to initialize at launch, so timing stays accurate no matter how long the app runs unattended.
* **Water-reminder default inconsistency** — the Settings view's fallback default for water-reminder frequency was 20 min while the registered app default is 60 min. Aligned to 60 min so the two can never diverge.

---

## [1.1.3] - 2026-06-29

### 🐛 Bug Fixes

* **Break/wellness overlay steals focus on secondary monitor** — on multi-monitor setups, iterating `NSScreen.screens` and calling `makeKeyAndOrderFront` on every screen meant the last window in the loop became the key window (often a secondary display). Primary screen window now calls `makeKeyAndOrderFront`; all others call `orderFront` only.
* **Potential crash in alert position calculation** — `alertOrigin` accessed `NSScreen.screens[0]` if `NSScreen.main` was nil, which crashes on an empty array. Changed to `NSScreen.screens.first` with a guard that returns `.zero` if both are nil.
* **Duplicate magic numbers for nudge positioning** — offsets `(+22, -58)` from cursor to nudge panel were duplicated at two callsites. Extracted to `nudgeOffsetX`/`nudgeOffsetY` constants so any future nudge size adjustment requires a single change.

---

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
