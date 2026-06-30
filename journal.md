# 🧘 SuperZen Engineering Journal

A running log of audits, bug fixes, stability work, and feature additions on the road to a public, Apple-worthy release. Newest entries on top.

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

### Flagged for later (NOT a regression — a feature gap)
**Day-progress windows can't cross midnight.** A night-shift user (e.g. 22:00→06:00) gets a
silent 0% bar because `updateDayProgress()` requires `dayEnd > dayStart`. Quiet-hours and the
focus schedule both already support wrap-around via `SchedulePolicy`; day-progress does not.
Fixing it well needs product decisions on what the bar shows when "now" sits outside a
wrapped window, so it's deferred rather than rushed. Tracked as a follow-up task.

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
