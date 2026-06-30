# 🧘‍♂️ SuperZen Changelog

## [1.1.0] - 2026-06-29

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

## [1.0.0] - 2026-02-25

### ✨ Features

* Initial High-Fidelity release.
* Unified Heartbeat Engine for wellness and breaks.
* Hardware-level Cursor Satellite tracking.
* High-density Fact-Based Insights dashboard.
* Adaptive "Don't Show While Typing" logic.
