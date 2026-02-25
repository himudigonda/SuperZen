import SwiftUI

struct LookAwayBreakScheduleView: View {
  @EnvironmentObject var stateManager: StateManager

  // Settings Bindings
  @AppStorage(SettingKey.dontShowWhileTyping) var dontShowTyping = true
  @AppStorage(SettingKey.breakReminderEnabled) var breakReminderEnabled = true
  @AppStorage(SettingKey.reminderDesign) var reminderDesign = "Default"
  @AppStorage(SettingKey.playReminderSound) var playReminderSound = true
  @AppStorage(SettingKey.countdownEnabled) var countdownEnabled = true
  @AppStorage(SettingKey.overtimeEnabled) var overtimeEnabled = true
  @AppStorage(SettingKey.overtimeEvenPaused) var overtimeEvenPaused = false
  @AppStorage(SettingKey.endBreakEarly) var endBreakEarly = true
  @AppStorage(SettingKey.lockMacAutomatically) var lockMacAutomatically = false

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {

      // SECTION 1: General
      VStack(alignment: .leading, spacing: 12) {
        Text("General").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)
        ZenCard {
          ZenRow(title: "Show breaks after", subtitle: "of focused screen time") {
            ZenDurationPicker(
              title: "Work", value: $stateManager.workDuration,
              options: [("10 seconds (Test)", 10), ("20 minutes", 1200), ("45 minutes", 2700)])
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Break duration") {
            ZenDurationPicker(
              title: "Break", value: $stateManager.breakDuration,
              options: [("4 seconds (Test)", 4), ("20 seconds", 20), ("1 minute", 60)])
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Don't show breaks while I'm typing or dragging") {
            Toggle("", isOn: $dontShowTyping).toggleStyle(.switch).tint(Theme.accent)
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          Button(action: {}) {
            ZenNavigationRow(
              icon: "figure.walk", title: "Long breaks",
              value: "Every 4th break is a 5 mins long break")
          }.buttonStyle(.plain)
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          Button(action: {}) {
            ZenNavigationRow(icon: "deskclock.fill", title: "Office hours", value: "Disabled")
          }.buttonStyle(.plain)
        }
      }

      // SECTION 2: Break Skip Difficulty
      VStack(alignment: .leading, spacing: 12) {
        Text("Break skip difficulty").font(.system(size: 13, weight: .bold)).foregroundColor(
          Theme.textPrimary)
        HStack(spacing: 14) {
          DifficultyCard(
            title: "Casual", subtitle: "Skip anytime", icon: "forward.end.fill",
            backgroundGradient: Theme.gradientCasual,
            isSelected: stateManager.difficultyRaw == "Casual"
          ) { stateManager.difficultyRaw = "Casual" }

          DifficultyCard(
            title: "Balanced", subtitle: "Skip after a pause", icon: "circle",
            backgroundGradient: Theme.gradientBalanced,
            isSelected: stateManager.difficultyRaw == "Balanced"
          ) { stateManager.difficultyRaw = "Balanced" }

          DifficultyCard(
            title: "Hardcore", subtitle: "No skips allowed", icon: "nosign",
            backgroundGradient: Theme.gradientHardcore,
            isSelected: stateManager.difficultyRaw == "Hardcore"
          ) { stateManager.difficultyRaw = "Hardcore" }
        }
      }

      // SECTION 3: Break Reminder
      VStack(alignment: .leading, spacing: 12) {
        Text("Break reminder").font(.system(size: 13, weight: .bold)).foregroundColor(
          Theme.textPrimary)
        ZenCard {
          ZenRow(title: "Show a reminder before a break appears") {
            Toggle("", isOn: $breakReminderEnabled).toggleStyle(.switch).tint(Theme.accent)
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Reminder design") {
            ZenSegmentedPicker(selection: $reminderDesign, options: ["Default", "Compact"])
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Show reminder") {
            HStack(spacing: 8) {
              ZenPickerPill(text: "1 minute")
              Text("before the break starts").font(.system(size: 13)).foregroundColor(
                Theme.textSecondary)
            }
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Keep the reminder visible for") {
            ZenPickerPill(text: "15 seconds")
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Play a sound when the reminder appears") {
            Toggle("", isOn: $playReminderSound).toggleStyle(.switch).tint(Theme.accent)
          }
        }
      }

      // SECTION 4: Countdown & Overtime (Side by Side Cards)
      HStack(alignment: .top, spacing: 16) {
        FeatureCardView(
          gradient: LinearGradient(
            colors: [Color(hex: "FF3E82"), Color(hex: "FF9D6C")], startPoint: .topLeading,
            endPoint: .bottomTrailing),
          pillIcon: "leaf.fill", pillText: "Starting break in 07",
          title: "Countdown before break",
          description: "A countdown that displays when a break is about to start"
        ) {
          ZenRow(title: "Enabled") {
            Toggle("", isOn: $countdownEnabled).toggleStyle(.switch).tint(.blue)
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          ZenRow(title: "Countdown duration") { ZenPickerPill(text: "10 seconds") }
        }

        FeatureCardView(
          gradient: LinearGradient(
            colors: [Color(hex: "FF2E4C"), Color(hex: "6A1B9A")], startPoint: .topLeading,
            endPoint: .bottomTrailing),
          pillIcon: "bolt.fill", pillText: "45 minutes without a break",
          title: "Overtime nudge",
          description:
            "Shows how long you've been working past your chosen screen time. Shake to dismiss."
        ) {
          ZenRow(title: "Enabled") {
            Toggle("", isOn: $overtimeEnabled).toggleStyle(.switch).tint(.blue)
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          ZenRow(title: "Show even when paused") {
            Toggle("", isOn: $overtimeEvenPaused).toggleStyle(.switch).tint(.blue)
          }
        }
      }

      // SECTION 5: More
      VStack(alignment: .leading, spacing: 12) {
        Text("More").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)
        ZenCard {
          ZenRow(title: "Let me \"End break\" early if nearly done") {
            Toggle("", isOn: $endBreakEarly).toggleStyle(.switch).tint(Theme.accent)
          }
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)

          ZenRow(title: "Lock my Mac automatically when a break starts") {
            Toggle("", isOn: $lockMacAutomatically).toggleStyle(.switch).tint(Theme.accent)
          }
        }
      }

    }
  }
}

// MARK: - Subcomponents

struct FeatureCardView<Content: View>: View {
  let gradient: LinearGradient
  let pillIcon: String
  let pillText: String
  let title: String
  let description: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)

      VStack(spacing: 0) {
        ZStack {
          gradient
          HStack(spacing: 6) {
            Image(systemName: pillIcon)
            Text(pillText)
          }
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(.white)
          .padding(.horizontal, 10).padding(.vertical, 6)
          .background(.ultraThinMaterial)
          .cornerRadius(8)
        }
        .frame(height: 100)

        VStack(alignment: .leading, spacing: 0) {
          Text(description)
            .font(.system(size: 11))
            .foregroundColor(Theme.textSecondary)
            .lineSpacing(4)
            .padding(16)
            .frame(minHeight: 70, alignment: .topLeading)

          Divider().background(Color.white.opacity(0.05))
          content
        }
      }
      .background(Theme.cardBG)
      .cornerRadius(10)
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    .frame(maxWidth: .infinity)
  }
}

struct DifficultyCard: View {
  let title: String
  let subtitle: String
  let icon: String
  let backgroundGradient: LinearGradient
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 12) {
        ZStack {
          backgroundGradient
          HStack(spacing: 8) {
            Image(systemName: icon)
            Text(isSelected ? "Selected" : "Skip Break")
          }
          .font(.system(size: 13, weight: .black))
          .foregroundColor(.white)
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(.black.opacity(0.2))
          .cornerRadius(6)
        }
        .frame(height: 90)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
            .shadow(radius: isSelected ? 5 : 0)
        )

        VStack(spacing: 4) {
          Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textPrimary)
          Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
        }
      }
      .frame(maxWidth: .infinity)
      .opacity(isSelected ? 1.0 : 0.7)
    }.buttonStyle(.plain)
  }
}
