import SwiftUI

/// First-run welcome flow. Shown full-window until the user finishes it, after which
/// `SettingKey.hasCompletedOnboarding` flips to true and `ContentView` takes over.
/// Designed to be skimmable in ~20 seconds: what it does, how it helps, and two
/// choices (intensity + launch-at-login) with sensible defaults already selected.
struct OnboardingView: View {
  @AppStorage(SettingKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
  @AppStorage(SettingKey.difficulty) private var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.workDuration) private var workDuration: Double = 1500
  @AppStorage(SettingKey.launchAtLogin) private var launchAtLogin = false

  @State private var step = 0
  private let totalSteps = 4

  private let workOptions: [(String, Double)] = [
    ("20 min", 1200), ("25 min", 1500), ("30 min", 1800), ("45 min", 2700), ("60 min", 3600),
  ]

  var body: some View {
    ZStack {
      ZenCanvasBackground()

      VStack(spacing: 28) {
        stepContent
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
          .transition(
            .asymmetric(
              insertion: .opacity.combined(with: .move(edge: .trailing)),
              removal: .opacity.combined(with: .move(edge: .leading))
            )
          )
          .id(step)

        footer
      }
      .padding(44)
    }
    .frame(minWidth: 720, idealWidth: 760, minHeight: 560, idealHeight: 600)
  }

  // MARK: - Steps

  @ViewBuilder private var stepContent: some View {
    switch step {
    case 0: welcomeStep
    case 1: howItWorksStep
    case 2: styleStep
    default: finishStep
    }
  }

  private var welcomeStep: some View {
    VStack(spacing: 24) {
      heroIcon("eye.fill")
      VStack(spacing: 12) {
        Text("Welcome to SuperZen")
          .font(.system(size: 34, weight: .bold, design: .rounded))
          .foregroundColor(Theme.textPrimary)
        Text("Your eyes and focus, looked after — automatically.")
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(Theme.textSecondary)
          .multilineTextAlignment(.center)
        Text(
          "SuperZen lives in your menu bar and gently reminds you to rest your eyes, "
            + "fix your posture, and take real breaks — following the 20-20-20 rule for healthy screen time."
        )
        .font(.system(size: 13))
        .foregroundColor(Theme.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 440)
        .padding(.top, 4)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var howItWorksStep: some View {
    VStack(spacing: 20) {
      stepHeading("How SuperZen helps", "Three quiet systems working in the background.")
      VStack(spacing: 0) {
        ZenFeatureRow(
          icon: "timer", title: "Focus blocks & breaks",
          subtitle: "Work in focused blocks, then a full-screen break to actually rest your eyes."
        ) { EmptyView() }
        ZenRowDivider()
        ZenFeatureRow(
          icon: "cursorarrow.motionlines", title: "Gentle nudges",
          subtitle: "A small pill follows your cursor before a break — no jarring interruptions."
        ) { EmptyView() }
        ZenRowDivider()
        ZenFeatureRow(
          icon: "figure.mind.and.body", title: "Wellness pulses",
          subtitle: "Quick posture, blink, hydration, and affirmation reminders through the day."
        ) { EmptyView() }
      }
      .padding(.vertical, 6)
      .background {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape.fill(.thinMaterial)
        shape.stroke(Theme.surfaceStroke, lineWidth: 1)
      }
      .frame(maxWidth: 520)
    }
  }

  private var styleStep: some View {
    VStack(spacing: 20) {
      stepHeading(
        "Pick your intensity", "How strict should breaks be? You can change this anytime.")
      VStack(spacing: 12) {
        ForEach(BreakDifficulty.allCases) { difficulty in
          OnboardingChoiceCard(
            title: difficulty.rawValue,
            subtitle: difficultyBlurb(difficulty),
            gradient: difficultyGradient(difficulty),
            isSelected: difficultyRaw == difficulty.rawValue
          ) {
            difficultyRaw = difficulty.rawValue
          }
        }
      }
      .frame(maxWidth: 520)

      VStack(spacing: 8) {
        Text("Focus block length")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(Theme.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        HStack(spacing: 8) {
          ForEach(workOptions, id: \.1) { option in
            durationPill(option.0, value: option.1)
          }
        }
      }
      .frame(maxWidth: 520)
      .padding(.top, 4)
    }
  }

  private var finishStep: some View {
    VStack(spacing: 24) {
      heroIcon("checkmark")
      VStack(spacing: 12) {
        Text("You're all set")
          .font(.system(size: 34, weight: .bold, design: .rounded))
          .foregroundColor(Theme.textPrimary)
        Text("SuperZen is now watching out for you from the menu bar, up top ↗")
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(Theme.textSecondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 440)
      }

      Toggle(isOn: $launchAtLogin) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Open SuperZen at login")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.textPrimary)
          Text("Recommended — so your eyes are protected every day without thinking about it.")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Theme.textSecondary)
        }
      }
      .toggleStyle(.switch)
      .tint(Theme.accent)
      .padding(16)
      .frame(maxWidth: 440)
      .background {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        shape.fill(.thinMaterial)
        shape.stroke(Theme.surfaceStroke, lineWidth: 1)
      }
      .onChange(of: launchAtLogin) { _, newValue in
        LaunchManager.shared.setLaunchAtLogin(newValue)
      }
    }
  }

  // MARK: - Footer (progress + navigation)

  private var footer: some View {
    HStack {
      if step > 0 {
        Button(action: { withAnimation(.snappy(duration: 0.28)) { step -= 1 } }) {
          Text("Back")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Theme.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go back")
      }

      Spacer()

      HStack(spacing: 7) {
        ForEach(0..<totalSteps, id: \.self) { index in
          Capsule()
            .fill(index == step ? Theme.accent : Theme.textSecondary.opacity(0.25))
            .frame(width: index == step ? 22 : 7, height: 7)
            .animation(.snappy(duration: 0.28), value: step)
        }
      }
      .accessibilityLabel("Step \(step + 1) of \(totalSteps)")

      Spacer()

      Button(action: advance) {
        Text(step == totalSteps - 1 ? "Start focusing" : "Continue")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(Capsule().fill(Theme.accentGradient))
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.defaultAction)
    }
  }

  // MARK: - Actions

  private func advance() {
    if step >= totalSteps - 1 {
      hasCompletedOnboarding = true
    } else {
      withAnimation(.snappy(duration: 0.28)) { step += 1 }
    }
  }

  // MARK: - Building blocks

  private func heroIcon(_ systemName: String) -> some View {
    ZStack {
      Circle()
        .fill(Theme.accentGradient)
        .frame(width: 104, height: 104)
        .shadow(color: Theme.accent.opacity(0.4), radius: 22, x: 0, y: 10)
      Image(systemName: systemName)
        .font(.system(size: 46, weight: .semibold))
        .foregroundColor(.white)
    }
    .accessibilityHidden(true)
  }

  private func stepHeading(_ title: String, _ subtitle: String) -> some View {
    VStack(spacing: 8) {
      Text(title)
        .font(.system(size: 26, weight: .bold, design: .rounded))
        .foregroundColor(Theme.textPrimary)
      Text(subtitle)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(Theme.textSecondary)
        .multilineTextAlignment(.center)
    }
    .padding(.bottom, 4)
  }

  private func durationPill(_ label: String, value: Double) -> some View {
    let isSelected = abs(workDuration - value) < 0.5
    return Button(action: { workDuration = value }) {
      Text(label)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(isSelected ? .white : Theme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
          Capsule().fill(
            isSelected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(.thinMaterial))
        )
        .overlay(Capsule().stroke(Theme.pillStroke, lineWidth: isSelected ? 0 : 1))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(label) focus blocks")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  private func difficultyBlurb(_ difficulty: BreakDifficulty) -> String {
    switch difficulty {
    case .casual: return "Skip breaks anytime — they're friendly suggestions."
    case .balanced: return "A short wait before you can skip. The recommended balance."
    case .hardcore: return "No skips. Commit fully to every break."
    }
  }

  private func difficultyGradient(_ difficulty: BreakDifficulty) -> LinearGradient {
    switch difficulty {
    case .casual: return Theme.gradientCasual
    case .balanced: return Theme.gradientBalanced
    case .hardcore: return Theme.gradientHardcore
    }
  }
}

/// A large, tappable selectable card used for the intensity choice.
private struct OnboardingChoiceCard: View {
  let title: String
  let subtitle: String
  let gradient: LinearGradient
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(gradient)
          .frame(width: 36, height: 36)
          .opacity(isSelected ? 1 : 0.55)

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Theme.textPrimary)
          Text(subtitle)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Theme.textSecondary)
            .multilineTextAlignment(.leading)
        }

        Spacer()

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 18))
          .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary.opacity(0.4))
      }
      .padding(14)
      .background {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        shape.fill(.thinMaterial)
        shape.stroke(isSelected ? Theme.accent : Theme.surfaceStroke, lineWidth: isSelected ? 2 : 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title) intensity. \(subtitle)")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}
