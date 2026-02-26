# 🧘‍♂️ SuperZen Changelog

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
