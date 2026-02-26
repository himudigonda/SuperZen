# 🧘‍♂️ SuperZen
### The High-Performance Digital Wellness Guardian for macOS.

**SuperZen** is a premium, native macOS utility designed to combat Computer Vision Syndrome (CVS) and physical fatigue. It acts as a silent guardian, using a sophisticated unified heartbeat engine to enforce the **20-20-20 rule** and maintain physical vitality through intelligent, non-intrusive reminders.

---

## ✨ Core Experience

SuperZen isn't just a timer; it’s a **context-aware health layer** for your Mac. 

### 📡 The Dual-Warning Nudge System
Before a mandatory break begins, SuperZen provides a two-layer warning system to ensure you're never caught off guard:
*   **The Satellite (Cursor Nudge):** A sleek, dark-frosted pill that follows your mouse cursor with zero-lag hardware tracking. It keeps the countdown in your peripheral vision without blocking your work.
*   **The Reminder Alert:** A rich, data-heavy dialogue box that appears in your chosen screen corner (Top Left, Center, or Right). it provides a "Big Picture" view of your focus streak and offers quick actions like "Start Now" or "Snooze."

### 🛡️ The Full-Screen Shield
When it’s time for a break, SuperZen utilizes the `CGShieldingWindowLevel`—the same level used by the macOS login screen—to create an unavoidable, beautiful atmosphere across all connected monitors.
*   **Wallpaper Mode:** Sample your actual desktop with a native Gaussian blur.
*   **Custom Mode:** Upload your own high-res imagery for a personalized rest experience.
*   **Opaque Gradient Mode:** A total sensory reset using deep, difficulty-reactive mesh gradients.

### 💓 Wellness Pulses
SuperZen periodically takes over the screen for 1.5 seconds to pulse high-priority reminders:
*   **Eye Care:** Reminds you to blink and reset your focal length.
*   **Posture:** A physical nudge to sit up straight and relax your shoulders.
*   **Hydration:** Tracks your water intake cadence.
*   **Affirmations:** A 4-second motivational boost to keep your mental state peak.

---

## 🧠 Smart Logic & Intelligence

SuperZen is built to be "Invisible until Necessary."

*   **Anti-Interruption Engine:** Using low-level `NSEvent` monitoring, the app detects if you are actively typing or dragging. If you are, it **freezes the deadline**, waiting until you pause your work before triggering a reminder.
*   **App Nap Protection:** SuperZen registers a `beginActivity` block with the kernel, ensuring that macOS never throttles the timer or kills the background engine, even during deep sleep or heavy CPU load.
*   **Absolute Deadline Timing:** All timers are calculated against absolute wall-clock timestamps (`Date`), making the countdown immune to system lag or frame drops.
*   **Smart Pause:** Automatically detects if you are in a meeting, playing a game, or watching a video to prevent embarrassing or distracting interruptions.

---

## 📊 Fact-Based Insights (No Lying)

We purged all "Bio-Score" heuristics to give you the raw, verifiable truth about your workday.
*   **Ocular Load:** A real-time measure of exactly how many minutes your eyes have been locked at a short focal length.
*   **Focus Density:** A verifiable ratio of active work vs. idle micro-breaks (phone checks, distractions).
*   **Compliance Audit:** A raw count of how many wellness nudges were actually completed vs. how many were shown.
*   **Intensity Heatmap:** A 24-hour distribution showing your peak focus hours.

---

## 🛠 Technical Architecture

*   **Language:** 100% Swift
*   **UI Framework:** SwiftUI & AppKit (Hybrid for maximum performance)
*   **Persistence:** SwiftData (Local-only, privacy-first)
*   **Tracking:** Core Graphics Event Tap (Hardware-level mouse tracking)
*   **Audio:** Reactive SoundManager supporting native system sound banks.

---

## 🚀 Performance
*   **Heartbeat:** 0.1s high-precision tick.
*   **Nudge Refresh:** 120Hz interpolation for buttery smooth movement.
*   **CPU Impact:** < 0.5% (Optimized background agents).

---

## 🎨 Inspiration & Attribution

This project takes significant inspiration from **LookAway**, the phenomenal digital wellness app created by **Kushagra Agarwal**. 

*SuperZen is an independent project and is not affiliated with Mystical Bits, LLC nor Kushagra Agarwal.*

---

**SuperZen: Focused Minds. Healthy Bodies.**
