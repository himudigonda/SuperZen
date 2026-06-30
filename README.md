# 🧘‍♂️ SuperZen

## The High-Performance Digital Wellness Guardian for macOS

**SuperZen** is a premium, native macOS utility designed to combat Computer Vision Syndrome (CVS) and physical fatigue. It acts as a silent guardian, using a sophisticated unified heartbeat engine to enforce the **20-20-20 rule** and maintain physical vitality through intelligent, non-intrusive reminders.

---

## 📦 Download & Install

1. Download the latest `SuperZen-x.y.z.dmg` from the [**Releases**](https://github.com/himudigonda/SuperZen/releases/latest) page.
2. Open the DMG and drag **SuperZen** into your **Applications** folder.
3. Launch it. SuperZen lives in your **menu bar** (look up top) — there's no Dock icon.
4. First launch only: if macOS says the app is from an unidentified developer, right-click the app → **Open** → **Open** to confirm.

> SuperZen requests Accessibility permission so it can detect typing/idle activity and avoid interrupting you mid-keystroke. All of this stays **100% on your device** — nothing is uploaded.

## 💻 Requirements

* **macOS 26.2 (Tahoe) or later** — SuperZen uses the latest native SwiftUI rendering (mesh gradients, glass materials) for its look and feel.
* A Mac with Apple Silicon or Intel.

---

## ✨ Core Experience

SuperZen isn't just a timer; it’s a **context-aware health layer** for your Mac.

### 📡 The Dual-Warning Nudge System

Before a mandatory break begins, SuperZen provides a two-layer warning system to ensure you're never caught off guard:

* **The Satellite (Cursor Nudge):** A sleek, dark-frosted pill that follows your mouse cursor with zero-lag hardware tracking. It keeps the countdown in your peripheral vision without blocking your work.
* **The Reminder Alert:** A rich, data-heavy dialogue box that appears in your chosen screen corner (Top Left, Center, or Right). it provides a "Big Picture" view of your focus streak and offers quick actions like "Start Now" or "Snooze."

### 🛡️ The Full-Screen Shield

When it’s time for a break, SuperZen utilizes the `CGShieldingWindowLevel`—the same level used by the macOS login screen—to create an unavoidable, beautiful atmosphere across all connected monitors.

* **Wallpaper Mode:** Sample your actual desktop with a native Gaussian blur.
* **Custom Mode:** Upload your own high-res imagery for a personalized rest experience.
* **Opaque Gradient Mode:** A total sensory reset using deep, difficulty-reactive mesh gradients.

### 💓 Wellness Pulses

SuperZen periodically flashes high-priority reminders — 0.75 seconds for physical cues, 2 seconds for affirmations:

* **Eye Care:** Reminds you to blink and reset your focal length.
* **Posture:** A physical nudge to sit up straight and relax your shoulders.
* **Hydration:** Tracks your water intake cadence.
* **Affirmations:** A motivational boost to keep your mental state peak.

---

## 🧠 Automation & Scheduling

* **Focus Schedules:** Define your "Office Hours" (e.g., Mon-Fri, 9-5). SuperZen automatically pauses enforcement outside these windows.
* **Quiet Hours:** Suppress wellness nudges during late-night sessions or early mornings to prevent "notification fatigue."
* **Resumable Cycles:** Choose between a "Hard Reset" after breaks or resuming your focus timer exactly where you left off.

---

## 📊 Deep Insights (Privacy-First Analytics)

SuperZen includes a comprehensive analytics engine. All data is stored locally via SwiftData and never leaves your Mac.

* **Focus Quality Score:** A proprietary 0-100 metric weighted by activity density, break compliance, and interruption frequency.
* **App Usage Tracking:** Identifies which applications dominate your focus blocks. See if Xcode, Slack, or Safari are consuming your productive windows.
* **Goal Forecasting:** Intelligent pacing that tells you when you'll hit your daily focus goal based on current momentum.
* **Trend Analysis:** Compare your current week/month against previous periods to visualize wellness improvements.

---

## 🛠 Technical Architecture

* **Language:** 100% Swift
* **UI Framework:** SwiftUI & AppKit (Hybrid for maximum performance)
* **Persistence:** SwiftData (Local-only, privacy-first)
* **Tracking:** Core Graphics Event Tap (Hardware-level mouse tracking)
* **Audio:** Reactive SoundManager supporting native system sound banks.

---

## 🚀 Performance

* **Heartbeat:** 1s drift-free tick driving all countdowns and wellness scheduling.
* **Nudge Refresh:** 120Hz cursor-tracking for buttery smooth movement.
* **Footprint:** Lightweight, event-driven background agents — designed to sit out of your way all day.

---

## 🏗 Build from Source

SuperZen is a standard Xcode project with a `justfile` for common tasks.

```bash
git clone https://github.com/himudigonda/SuperZen.git
cd SuperZen

# Open in Xcode and hit Run, or use the command line:
just build     # debug build
just test      # run the full unit-test suite
just dmg       # produce a distributable .dmg
```

**Tooling:** Xcode (matching the macOS requirement above), plus `swift-format`, `swiftlint`, and `create-dmg` for the `format` / `lint` / `dmg` recipes (`brew install swiftlint swift-format create-dmg`).

---

## 🎨 Inspiration & Attribution

This project takes significant inspiration from **LookAway**, the phenomenal digital wellness app created by **Kushagra Agarwal**.

*SuperZen is an independent project and is not affiliated with Mystical Bits, LLC nor Kushagra Agarwal.*

---

**SuperZen: Focused Minds. Healthy Bodies.**
