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

### Build / test
_(running — see next entry)_
