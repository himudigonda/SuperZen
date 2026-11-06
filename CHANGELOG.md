# 🧘‍♂️ SuperZen Changelog

## [Unreleased]

### ✨ Changes

* **Banner breaks**: in Appearance, Break style can show a break as a small banner at the top of the screen instead of covering it. Hardcore always uses the full screen.
* **Later keeps its place** on the break screen and stays dimmed until it can be used, so the other buttons no longer move.

## [0.1.0] - 2026-11-03

A ground-up rebuild. The timer, telemetry, overlays, settings, menu bar and Insights were rewritten around a tested core, and the defaults now follow the 20-20-20 rule the app is named for.

### ✨ Changes

* **Runs on macOS 15 Sequoia and later**, on Apple silicon and Intel. Launch is checked on both in CI.
* **Pause for a set time** from the menu bar: 15 minutes, 1 hour, 2 hours or until tomorrow.
* **Later** puts off a break a limited number of times without counting it as skipped.
* **Planned breaks** fire at the times and on the days you choose.
* **Breaks wait for what you are doing**: during calls, in apps you list and optionally in fullscreen apps, for no longer than the limit you set. A Hardcore break can be skipped if a call starts.
* **Presets** for 20-20-20, Pomodoro, deep work and a gentle schedule.
* **Break tips** under the timer, a today summary in the menu bar, and a skip pattern card in Insights.
* **Export** breaks, wellness and focus sessions from Insights as CSV or JSON.
* **Automation**: Shortcuts actions and a `superzen://` URL scheme for starting, skipping, pausing and resuming.
* **Reset** any settings section to its defaults, **copy diagnostics** from About, and turn app usage tracking off in Advanced.
* Break and reminder screens stay readable on any wallpaper, with a progress bar and matching actions.
* **Material 3 redesign.** Every screen, popover, overlay, menu, dialog and tooltip now uses Google's Material 3 language: tonal colour roles generated from your accent palette, Google Sans, the M3 type and shape scales, state layers, filled, tonal, outlined and text buttons, M3 switches, chips, sliders and progress indicators.
* The window has a new navigation drawer that collapses to a rail, plus a top app bar. Your accent palette and contrast profile carry over unchanged.
* Wellness reminders use symbols instead of emoji.
* **New timer engine.** All timing decisions now live in `Packages/SuperZenCore`, a Foundation-only reducer with absolute deadlines and an injected clock, tested on Linux CI.
* **20-20-20 by default**: 20 minutes of focus, a 20 second eye break, and a 5 minute long break every 4th cycle.
* Typing defers a break by at most 2 minutes. Stepping away for 2 minutes or more counts as a natural break, even when the screen locks or the Mac sleeps partway through.
* Blink reminders now come every 10 minutes and posture every 30, so they no longer land on top of the 20 minute eye break. Anyone still on the old shared 20 minute cadence moves over once. A reminder that comes due during a break waits until the middle of the next focus block.
* Sleep, wake, screen lock and fast user switching pause the timer instead of logging fake focus or firing an instant break.
* Global shortcuts use Carbon hotkeys, so SuperZen no longer asks for Accessibility access. Settings flags shortcuts that clash with macOS, another app, or each other.
* Overlays go through one coordinator: break screens and wellness pulses rebuild when displays are plugged in or rearranged.
* **Insights rebuilt on intervals.** Telemetry now stores focus and idle intervals, breaks with an outcome (completed, skipped or natural) and wellness results, in a versioned SwiftData schema. Old history is imported once on first launch.
* Stats come from a pure `InsightsCalculator` that splits time by local hour and day, so midnight and daylight saving changes are counted correctly.
* The streak includes today once the goal is met, the quality score shows a dash until there is data, the forecast uses your workday hours, and the trend compares the same slice of the previous period.
* **New Insights screen** built on Swift Charts: a headline row for focus against goal, breaks, streak and quality, a focus trend per range, a timeline of today's focus, idle time and breaks, and a 7 day heatmap of focus by hour. It refreshes live as telemetry is saved, has empty states and VoiceOver descriptions, and deleting history now asks first and reports what was removed.
* **New menu bar popover** with the next break time, a progress ring, day progress, and Start, Skip, Snooze and Pause actions.
* **Settings save as you change them**, with inline validation for impossible combinations such as a heads-up longer than the focus block. The Save button is gone.
* **New design system**: shared colour, type, spacing, radius, elevation and motion tokens, with one set of cards, rows, pickers and stat tiles across the app.
* **Refreshed onboarding** that explains the 20-20-20 rule and sets your focus block and break style.

### ♿ Accessibility and localization

* Break screens, the pre-break nudge and wellness reminders are announced to VoiceOver.
* Every control has a label, and the reminder card reads its countdown before its buttons.
* All motion honours Reduce Motion. The cursor nudge snaps to the pointer instead of gliding.
* Increase Contrast raises the app's contrast profile.
* Times follow the locale, including 24-hour clocks, and the weekday picker starts on the locale's first day.
* Spanish, French and German now cover every screen added in this release (211 new strings), picker options are translated, counts use proper plurals, and 78 unused strings were removed. A test keeps every entry translated with matching placeholders.

### 🐛 Bug Fixes

* The main window no longer opens at login. Opening SuperZen again from Finder or Spotlight brings it up.
* Starting a break or opening SuperZen from the menu bar closes the popover, and focus returns to the app you were in when the break ends.
* Only one copy of SuperZen runs at a time.
* A shortcut held by another app recovers on its own once that app lets go of it.
* Installs from before 2.0 that never changed their break settings keep their 25 minute focus and 5 minute break instead of moving to 20-20-20.
* Turning on launch at login during onboarding reflects what is already set, so finishing onboarding cannot remove an existing login item.
* A heads-up as long as the focus block no longer pins the nudge for the whole block. Custom durations have sensible minimums.
* Day progress accepts overnight windows, and the Appearance screen says when a custom break image has gone missing.
* Telemetry lives in its own store, so it can no longer collide with other apps.
* A schedule sleep now closes the focus session, and resuming outside schedule hours is no longer undone on the next tick.
* Skips from the nudge are logged, paused time no longer counts as rest, and an extended break skipped early is not counted as completed.
* The first focus session of each launch is saved, because telemetry is set up at launch instead of when the window opens.
* The Mac can idle sleep again while SuperZen runs.
* Wellness pulses never take focus or block clicks, and previewing one in Settings no longer closes a live break.
* The Lock button no longer crashes when the private lock API is missing; it falls back to display sleep and resumes the break if the Mac did not lock.
* After a break, keyboard focus goes back to the app you were using.
* Break time no longer counts toward the app usage of the focus block before it.
* History older than the retention window is pruned every day, not only at launch.
* A damaged telemetry store is moved aside and recreated instead of crashing the app at launch.
* Telemetry saves are batched and logged through `os.Logger`.

### 🛠 Internals

* CI runs the core package on Linux, the app and UI tests on macOS, and shellcheck plus the release script tests, with coverage summaries.
* Releases are cut by tag. `just ship` checks the tree, version and changelog, runs lint and tests, and the Release workflow builds, optionally signs and notarizes, and publishes the DMG with a checksum.
* The single 2,500 line test file was replaced by focused, parameterized suites that never touch your real settings.

---
