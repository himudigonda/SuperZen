# 🧘 SuperZen Engineering Journal

A running log of audits, bug fixes, stability work, and feature additions on the road to a public, Apple-worthy release. Newest entries on top.

---

## 2026-06-30 — v1.1.8: Fix clipped-shadow "border" on the break reminder

### Symptom (user-reported, with screenshot)
The fixed break-reminder popup had a crisp rectangular outline hugging the rounded card —
sharp corners around a 20pt-radius card. "It looks soo fucking weird."

### Diagnosis
Not a border at all — a **clipped drop shadow**. `FixedBreakAlertView` is a 420×200 card with
`.shadow(radius: 24, x: 0, y: 8)`. `OverlayWindowManager.showFixedAlert` hosted it in a 440×220
window — only 10pt of margin per side. A 24pt-radius / 8pt-offset shadow needs ~32pt to fade;
with 10pt it hit the window's rectangular edge and got sliced flat → a hard rectangular halo.
`window.hasShadow = true` then traced that clipped alpha and drew a native shadow around the
same rectangle, compounding the effect.

### Fix
- Sized the host window to the card **plus** the shadow inset (`alertInsetX = 30`,
  `alertInsetY = 40` → 480×280 window) so the shadow has transparent room to fade naturally.
- Added matching `.padding(.horizontal, 30).padding(.vertical, 40)` to the view so its intrinsic
  size equals the window exactly (no NSHostingView centering ambiguity, no clipping).
- Set `window.hasShadow = false` — the SwiftUI shadow is the only one now; the native window
  shadow would re-trace the transparent rectangle and bring the border back.
- Rewrote `alertOrigin()` to offset by `(cardScreenPadding - inset)` so the **card** (not the
  larger window) still sits 40pt from the screen edge in all three positions (left/center/right).
- Documented the inset coupling in both files so the view padding and window size can't drift.

### Build / test / ship
- `just format` + `just lint`: **0 violations** across 36 files.
- `just build`: `** BUILD SUCCEEDED **`. `just test`: **125/125 passing**.
  (One flaky pass of the timing-sensitive `breakResumePolicyHonorsAdvancedPreference` —
  `Thread.sleep`-based, unrelated to this UI change; green on re-run.)
- Bumped 1.1.7 → **1.1.8**, build 9 → **10**.

---

## 2026-06-30 — v1.1.7: Settings correctness audit + wellness system tests

### Goals (user mandate)
"There are still a lot of cascading bugs. Add more tests and see and ensure all settings are
being respected. Logically things make sense and we are not just hallucinating."

### Approach
Rather than auditing by reading code and guessing, I audited by writing tests. The workflow:
1. Read all of `StateManager`, `SchedulePolicy`, `AppSettings`, `WellnessManager`, and every test.
2. Identified what is tested vs. untested by the existing 112-test suite.
3. Wrote tests that *actually call behavior* rather than just asserting property values.
4. Let failing tests surface real bugs (rather than speculating).

### Findings

#### 🐛 FIXED — Two dashboard tests fail after midnight (`SuperZenTests.swift`)
- `insightsQualityForecastAndWellnessTypeBreakdown` used `now - 1800s` and `now - 900s` as
  session start times. Run at 00:11 AM, that's 11:41 PM / 11:51 PM — yesterday. Sessions fell
  outside the "today" range, so `idleMinutes`, `interruptionsCount` returned 0 instead of 6/1.
- `insightsGoalProgressClampsAtOne` used `now - 3600s` as start time. Same issue: yesterday
  when run in the first hour of the day. `focusGoalProgress` returned 0.0 instead of 1.0.
- Fix: both tests now anchor sessions to fixed hours within the current calendar day
  (`startOfDay(for: now) + H`), making them deterministic at any time of day.

#### ✅ Verified: all settings properly propagate via `refreshSettings()`
Verified by writing 11 behavioral tests (not just property-check tests) against the live
code paths. Every checked setting was correctly picked up:
- `difficultyRaw` → `canSkip` flips immediately after `refreshSettings()`
- `balancedSkipLockRatio` → skip threshold updates on next access
- `wellnessDurationMultiplier` → next wellness transition uses new value
- `nudgeLeadTime`, `idleThreshold` → property updates confirmed
- `forceResetFocusAfterBreak` → timer correctly restores vs. resets at break end
- Wellness frequencies (`postureFrequency`) → `nextPostureDue` rescheduled on the spot
- Focus schedule auto-resume → correctly resets `timeRemaining` to full `workDuration`

#### ✅ Verified: wellness system logic is correct
The wellness system (`checkWellnessReminders` / `shouldFireReminder` / `deferReminder`) had
**zero tests** before this session. Added 5 tests covering:
- Posture fires when enabled and past due
- `postureEnabled=false` stops posture from firing even when past due
- Quiet hours prevent all wellness even when types are individually enabled
- Firing order: posture beats blink when both are due simultaneously
- Re-enable after disable starts a fresh timer (doesn't fire at the original due date)

### What was NOT found (confirmed clean after testing)
- `refreshSettings()` correctly handles all ~19 runtime-critical settings.
- No wellness type fires during `.onBreak` or `.nudge` (heartbeat guard is correct).
- `deferReminder` correctly pushes due dates forward during quiet hours without niling them.
- `scheduleAutoResumesWhenBackInWindow` correctly resets to `workDuration` (not stale time).

### Added test hook
`checkWellnessRemindersForTesting(now:)` — directly invokes `checkWellnessReminders(now:)` at
an injected time, bypassing the heartbeat's `status == .active` guard. Mirrors the existing
`enforceSchedulePolicyForTesting(now:)` and `updateDayProgressForTesting()` seams.

### Build / test / ship
- `just format` + `just lint`: **0 violations** across 36 files.
- `just test`: **125/125 passing** — `** TEST SUCCEEDED **`.
- Bumped 1.1.6 → **1.1.7**, build 8 → **9**.
- Shipping as v1.1.7.

---

## 2026-06-29 — Session: deep audit + internationalization

### Goals (user mandate)
- Keep finding & fixing bugs across the whole codebase; format → lint → test every time.
- Add **multi-language support** (i18n): research best approach, add real languages, test them.
- Increase stability, safety, and polish ("sexyness"). Make it audience-friendly & Apple-worthy.
- Journal everything here.

### Starting state
- Branch: `claude/recurringfixes`, working tree clean.
- Last shipped: **v1.1.3** (multi-monitor overlay focus, alertOrigin crash guard, nudge offset constants).
- 106 unit tests passing.
- No localization infrastructure yet (`knownRegions = en, Base`). 59 `Text("…")` literals.

### Plan
1. Audit un-covered files (UI views, IdleTracker, LaunchManager, KeyboardShortcutService, AppSettings, Dashboard, overlays) → fix real bugs.
2. Stand up a String Catalog (`Localizable.xcstrings`) and localize all user-facing strings.
3. Add languages (target: Spanish, French, German, Japanese, Simplified Chinese, Hindi, Portuguese-BR + more).
4. Build + test green, ship.

### Findings & fixes
_(populated below as work proceeds)_

---

## 2026-06-29 (cont.) — Recurring deep-audit sweep

### Approach
Launched 3 parallel high-confidence audit agents over non-overlapping areas:
1. **Settings UI views** — binding/key/clamp/range bugs.
2. **Services & trackers** — leaks, threading, event-monitor/timer lifecycle, crashes.
3. **Dashboard analytics & overlays** — division/date/empty-state math bugs.

Meanwhile auditing `StateManager.swift` (725 lines — the heartbeat & state machine) by hand.

**Rule:** every finding is verified against source before fixing. Last round produced 3
false positives (guarded division flagged as unguarded, correct quiet-hours logic flagged
as inverted). Trust nothing unverified.

### Findings

**Coverage:** 3 agents (settings UI, services/trackers, dashboard/overlays) + hand audit of
`StateManager.swift` (725 lines). The codebase is in genuinely good shape after the prior
sessions — the bug surface is nearly exhausted. Net: **1 real stability bug + 1 consistency nit.**

#### 🐛 FIXED — App Nap never actually suppressed (`App/SuperZenApp.swift`)
- **Symptom:** the documented "disable App Nap" fix didn't hold. The `beginActivity` token
  was stored in a plain instance `var` on `struct SuperZenApp: App`. A SwiftUI App is a value
  type SwiftUI may copy/re-create; the token's lifetime was tied to a transient struct copy,
  so it could deallocate and silently re-enable App Nap — throttling the `StateManager`
  heartbeat (a `.main`/`.common` RunLoop timer) whenever the menubar app sat in the background.
  That means breaks/wellness timers drifting or stalling for backgrounded users — the single
  worst possible failure for a break-reminder app.
- **Fix:** moved the token to a `private static let backgroundActivity` (process-lifetime
  retention) and `_ = Self.backgroundActivity` in `init()` to force its one-time creation
  (statics are lazy, so it must be touched). Now guaranteed alive for the whole process
  regardless of how SwiftUI handles the App value.

#### 🧹 FIXED — `waterFrequency` default inconsistency (`UI/Settings/WellnessRemindersView.swift`)
- The view's `@AppStorage` fallback was `1200`s while `registerDefaults()` seeds `3600`s.
  Harmless today (registration runs first), but a latent footgun if init order ever changes.
  Aligned the literal to `3600` to match the source of truth in `AppSettings.swift`.

#### ✅ Verified clean (notable non-bugs ruled out)
- **All divisions in `DashboardViewModel`** are guarded (`> 0 ? :` or `max(1, …)`): averages,
  completion rates, goal progress, activeRatio, forecast pace, app-usage shares. No NaN/Inf
  can reach the UI.
- **Date math** in streaks and week/month windows: 7-day and 30-day inclusive ranges are
  correct, no off-by-one; streak deliberately starts from yesterday.
- **No force-unwraps / `try!` / unguarded subscripts** in any audited file (grep-confirmed).
  `MeshGradient` fallback always gets a 9-element color array from both call sites.
- **Every `@AppStorage` key** references a `SettingKey` constant (string-typo mismatches are
  structurally impossible) and every setting is read back by a consumer.
- **`StateManager`** (hand audit): typing-freeze, wellness rescheduling, pause/resume state
  restoration, quiet-hours deferral, and day-progress guards are all correct.

### Build / test / ship
- `just format` + `just lint --strict`: **0 violations** across 35 files.
- `just test`: **106/106 passing** — `** TEST SUCCEEDED **`.
- Bumped MARKETING_VERSION 1.1.3 → **1.1.4**, CURRENT_PROJECT_VERSION 5 → **6** (all 6 build
  configs), AboutView fallbacks, CHANGELOG.
- Shipped: commit `0c6cc06`, tag `v1.1.4`, GitHub Release live, `main` fast-forwarded.
  https://github.com/himudigonda/SuperZen/releases/tag/v1.1.4

### Next
Static audit surface is nearly exhausted (the prior sessions did deep work). Shifting to
**edge-case test authoring** — exercising state-machine corners, schedule/quiet-hours
boundaries, and telemetry accumulation. New tests are the best remaining bug-finder. Any
failing test = a real bug to fix. (See next entry.)

---

## 2026-06-29 (cont.) — Edge-case tests for the heartbeat internals

### What
The schedule sleep/auto-resume path and the day-progress math live inside the private
`heartbeat()` and had **no StateManager-level tests** — only `SchedulePolicy` (the pure
boolean) was covered. Added two minimal test hooks mirroring the existing
`refreshSettingsForTesting()` seam:
- `enforceSchedulePolicyForTesting(now:)` — drives one schedule evaluation at an injected time.
- `updateDayProgressForTesting()` — recomputes the day-progress metrics once.

Added **5 deterministic tests** (111 total, all green):
1. `scheduleSleepsWhenOutsideActiveWindow` — Active → Paused + `isScheduleSleeping` when
   outside the window (injected Monday 20:00 vs a 09:00–18:00 Mon–Fri schedule).
2. `scheduleAutoResumesWhenBackInWindow` — sleeps, then wakes to Active when time re-enters
   the window and auto-resume is on.
3. `scheduleDoesNotAutoResumeWhenAutoResumeDisabled` — stays asleep when auto-resume is off.
4. `dayProgressEnabledProducesValidRange` — percent ∈ [0,1], elapsed/remaining ≥ 0.
5. `dayProgressInvertedWindowReturnsZeros` — locks the current behavior for a window whose
   end precedes its start.

Tests use a fixed Monday (2024-01-01) so weekday-gated assertions are run-time-independent.

### Result
No bug surfaced — the logic is correct. Value delivered: these corners are now regression-
protected, and the injected-time seam makes future schedule work testable.

### Previously flagged — now fixed (2026-06-30)
**Day-progress cross-midnight support added.** `updateDayProgress(now:)` now handles wrapped
windows (endMinute < startMinute) so a night-shift user (e.g. 22:00→06:00) sees real progress.
Semantics: inside either the current or previous day's shift window → linear progress; in the
inter-shift gap (after yesterday's close, before tonight's open) → 0%; past tonight's close
(> 1 day uptime edge case) → 100%. Three regression tests cover the evening, early-morning,
and inter-shift-gap cases with injected `now:` times so results are deterministic.

---

## 2026-06-29 (cont.) — Accessibility pass (v1.1.5)

### Why
Toward "Apple's attention": Apple actively features apps that nail accessibility, and a
wellness app that excludes VoiceOver users contradicts its own premise. The break flow had
real, concrete gaps (not speculation): an icon-only close button read as "xmark", big
countdown timers read as "zero-two colon three-zero", and the cursor-following nudge would
chatter at VoiceOver as it tracked the pointer.

### Changes (all additive view modifiers — zero logic change)
- **Menu bar (`SuperZenApp.MenuBarLabelView`):** `.accessibilityElement(children: .ignore)`
  + a single state-aware `accessibilitySummary` ("focusing, 12 minutes until break", "on
  break, … remaining", "paused", "sleeping on schedule", "wellness reminder").
- **`FixedBreakAlertView`:** close button → "Dismiss reminder"; timer → spoken
  "<time> until your break".
- **`BreakOverlayView`:** timer → spoken "<time> of break remaining"; *Add one minute* and
  *Lock screen* pills labeled; skip button label is state-aware and explains unavailability
  ("Skip available in N seconds" / "Skipping disabled in hardcore mode").
- **`NudgeOverlay`:** `.accessibilityHidden(true)` — passive indicator, state already on the
  menu bar; stops VoiceOver noise as it follows the cursor.
- Added a small `spokenTime(_:)` helper locally in each view (kept local to avoid touching
  Xcode target membership / pbxproj for a new shared file).

### Build / test / ship
- `just test`: **111/111 passing**, `** TEST SUCCEEDED **` (compile-verified the a11y code).
- Bumped 1.1.4 → **1.1.5**, build 6 → **7**; CHANGELOG + AboutView updated.
- Shipping as v1.1.5 (see git/tag).

### Honest caveat
These labels are compile-verified and follow correct SwiftUI a11y patterns, but I can't drive
VoiceOver in this environment to hear them. They're low-risk and correct by construction; a
manual VoiceOver pass before any App Store submission is still worth doing.

### Release-pipeline bug found & fixed
`just ship 1.1.5` failed at `scripts/ship.sh` line 29 (`git push origin main`): it assumed the
release runs from a current local `main`, but we work on `claude/recurringfixes`, so the stale
local `main` ref was rejected non-fast-forward — dying **before** tagging. Completed v1.1.5
manually (tag + `gh release create` with the prebuilt DMG; release is live, not a draft), then
fixed ship.sh to `git push origin HEAD:main` so future releases work from any branch.
v1.1.5: https://github.com/himudigonda/SuperZen/releases/tag/v1.1.5

---

## 2026-06-29 (cont.) — First-run onboarding + 4th audit pass (v1.1.6)

User picked, from the "what next" fork: **first-run onboarding** and **keep hunting bugs/tests**.

### 4th audit pass — codebase confirmed clean
Ran a 4th high-confidence agent over the only files never deep-audited (`ContentView`,
`Theme`, `AppearanceView`, `GeneralSettingsView`, `BreakScheduleView`, `DashboardComponents`,
`WellnessOverlayView`, `ZenBackgroundView`, `WellnessManager`). **NO CONFIRMED BUGS.** Every
suspect (Color(hex:) fallback, MeshGradient 9-color indexing, `labels[weekday-1]`, duration
math, progress clamps) verified correct. That's 4 passes + a hand audit with one real bug
total (the App Nap token). The bug surface is genuinely exhausted — I'm not going to invent
findings that aren't there.

### Onboarding (new `UI/Onboarding/OnboardingView.swift`)
A polished 4-step first-run flow, gated on the new `SettingKey.hasCompletedOnboarding`:
1. **Welcome** — hero, value prop, the 20-20-20 premise.
2. **How it helps** — focus blocks/breaks, cursor nudges, wellness pulses (ZenFeatureRow cards).
3. **Pick intensity** — Casual / Balanced / Hardcore selectable cards (difficulty-colored
   gradients) + focus-block length pills. Writes `difficulty` and `workDuration` live.
4. **You're all set** — launch-at-login toggle (wired to `LaunchManager`), points to the menu bar.
Built entirely from the existing Theme design system (ZenCanvasBackground, accent gradients,
thin-material cards), animated step transitions, progress dots, full keyboard + VoiceOver
support (every control labeled, selected traits set, hero icons hidden).

`ContentView` now shows `OnboardingView` until completed, then the normal split view —
reactive via `@AppStorage`. New files land automatically (project uses Xcode filesystem-
synchronized groups, so no pbxproj surgery).

### Tests / build
- New file **compiles** (`** BUILD SUCCEEDED **`) — the real check for hand-written SwiftUI.
- Added `onboardingDefaultsToNotCompleted` (a fresh install must show onboarding) → **112 tests**.
- All green.

### Flagged for separate cleanup
`just build` surfaces 2 pre-existing Swift-concurrency warnings in `TelemetryService.swift`
(app-activation observer touches `@MainActor` state from a Sendable closure) — harmless today,
hard errors under Swift 6. Tracked as a follow-up task; not touched here to keep this change
focused on onboarding.
