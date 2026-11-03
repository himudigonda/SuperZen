import SuperZenCore
import SwiftUI

struct OnboardingView: View {
  @AppStorage(SettingKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
  @AppStorage(SettingKey.difficulty) private var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.workDuration) private var workDuration: Double = SettingsCatalog.workDurationDefault
  @AppStorage(SettingKey.launchAtLogin) private var launchAtLogin = false

  @State private var step: OnboardingStep
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(initialStep: OnboardingStep = .welcome) {
    _step = State(initialValue: initialStep)
  }

  private var difficulty: BreakDifficulty {
    BreakDifficulty(rawValue: difficultyRaw) ?? .balanced
  }

  var body: some View {
    HStack(spacing: 0) {
      OnboardingStage(step: step, difficulty: difficulty, workDuration: workDuration)
        .frame(width: 400)
        .frame(maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 0) {
        progress
          .padding(.bottom, ZenSpacing.xxl)

        stepContent
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .transition(
            .asymmetric(
              insertion: reduceMotion ? .opacity : .opacity.combined(with: .offset(y: ZenSpacing.sm)),
              removal: .opacity)
          )
          .id(step)

        footer
          .padding(.top, ZenSpacing.lg)
      }
      .padding(.horizontal, ZenSpacing.xxxl)
      .padding(.top, ZenSpacing.xxl)
      .padding(.bottom, ZenSpacing.xxl)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(ZenColor.surface)
    .frame(minWidth: 880, idealWidth: 920, minHeight: 640, idealHeight: 660)
  }

  @ViewBuilder private var stepContent: some View {
    switch step {
    case .welcome: welcomeStep
    case .rule: ruleStep
    case .rhythm: rhythmStep
    case .intensity: intensityStep
    case .finish: finishStep
    }
  }

  private var welcomeStep: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.lg) {
      Text("Welcome to SuperZen")
        .font(ZenFont.onboardingTitle)
        .foregroundStyle(ZenColor.onSurface)
        .accessibilityAddTraits(.isHeader)
      Text("Healthy screen time, without having to think about it.")
        .font(ZenFont.titleLarge)
        .foregroundStyle(ZenColor.onSurface)
        .fixedSize(horizontal: false, vertical: true)
      Text(
        String(
          localized:
            "Long stretches at a screen strain your eyes, back and focus. SuperZen sits quietly in your menu bar and paces your day with short, well-timed breaks.",
          comment: "Onboarding welcome step body")
      )
      .font(ZenFont.bodyMedium)
      .foregroundStyle(ZenColor.onSurfaceVariant)
      .lineSpacing(ZenSpacing.xxs)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var ruleStep: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.lg) {
      stepHeading(
        String(localized: "The 20-20-20 rule", comment: "Onboarding step title"),
        String(
          localized: "Eye care professionals recommend it to ease digital eye strain. SuperZen runs it for you.",
          comment: "Onboarding step subtitle"))
      Text(
        String(
          localized:
            "Every 20 minutes, look at something 20 feet away for 20 seconds. That tiny pause lets the focusing muscles in your eyes unclench.",
          comment: "Onboarding 20-20-20 explanation")
      )
      .font(ZenFont.bodyMedium)
      .foregroundStyle(ZenColor.onSurfaceVariant)
      .lineSpacing(ZenSpacing.xxs)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var rhythmStep: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.lg) {
      stepHeading(
        String(localized: "How a cycle feels", comment: "Onboarding step title"),
        String(localized: "Gentle by default, firm when it matters.", comment: "Onboarding step subtitle"))

      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        OnboardingFeature(
          icon: "cursorarrow.motionlines",
          title: String(localized: "A heads-up first", comment: "Onboarding feature row title"),
          detail: String(
            localized: "A small pill follows your cursor a few seconds before each break, so nothing jumps at you.",
            comment: "Onboarding feature row subtitle"))
        OnboardingFeature(
          icon: "eye.slash",
          title: String(localized: "A short eye break", comment: "Onboarding feature row title"),
          detail: String(
            localized:
              "The screen softens for \(DurationFormat.compact(SettingsCatalog.breakDurationDefault)). Look away and let your eyes rest.",
            comment: "Onboarding feature row subtitle with the eye break length"))
        OnboardingFeature(
          icon: "figure.walk",
          title: String(localized: "A longer reset", comment: "Onboarding feature row title"),
          detail: String(
            localized:
              "Every \(SettingsCatalog.ordinal(SettingsCatalog.longBreakEveryDefault)) break lasts \(DurationFormat.compact(SettingsCatalog.longBreakDurationDefault)). Stand up, stretch, refill your water.",
            comment: "Onboarding feature row subtitle with the long break cadence and length"))
        OnboardingFeature(
          icon: "keyboard",
          title: String(localized: "Respectful of your flow", comment: "Onboarding feature row title"),
          detail: String(
            localized:
              "Mid-sentence? SuperZen waits up to \(DurationFormat.compact(SettingsCatalog.typingDeferralCapDefault)) while you type. Stepping away counts as a break too.",
            comment: "Onboarding feature row subtitle with the typing cap"))
      }

      Spacer(minLength: 0)

      FocusLengthPicker(value: $workDuration, options: SettingsCatalog.workDurationOptions)
    }
  }

  private var intensityStep: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.lg) {
      stepHeading(
        String(localized: "Pick your intensity", comment: "Onboarding step title"),
        String(
          localized: "How strict should breaks be? You can change this anytime.",
          comment: "Onboarding step subtitle"))
      VStack(spacing: ZenSpacing.sm) {
        ForEach(BreakDifficulty.allCases) { option in
          OnboardingChoiceCard(
            title: option.displayName,
            subtitle: difficultyBlurb(option),
            icon: difficultyIcon(option),
            isSelected: difficulty == option
          ) {
            withZenAnimation(.quick, reduceMotion: reduceMotion) { difficultyRaw = option.rawValue }
          }
        }
      }
    }
  }

  private var finishStep: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.lg) {
      Text("You're all set")
        .font(ZenFont.onboardingTitle)
        .foregroundStyle(ZenColor.onSurface)
        .accessibilityAddTraits(.isHeader)
      Text(
        String(
          localized:
            "Your first focus block (\(DurationFormat.compact(workDuration))) starts now. Find SuperZen in the menu bar, up top.",
          comment: "Onboarding finish message; the argument is the focus length")
      )
      .font(ZenFont.bodyMedium)
      .foregroundStyle(ZenColor.onSurfaceVariant)
      .lineSpacing(ZenSpacing.xxs)
      .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 0) {
        LabeledToggle(
          String(localized: "Open SuperZen at login", comment: "Onboarding launch at login toggle"),
          subtitle: String(
            localized: "Recommended, so your eyes are looked after every day.",
            comment: "Onboarding launch at login toggle subtitle"),
          isOn: $launchAtLogin)
        CardDivider()
        SettingRow(
          String(localized: "Need a break right now?", comment: "Onboarding shortcut hint title"),
          subtitle: String(
            localized: "Press \(SettingsCatalog.shortcutStartBreakDefault) from any app.",
            comment: "Onboarding shortcut hint subtitle with the start break shortcut"))
      }
      .zenSurface(cornerRadius: ZenRadius.md)
      .onAppear { launchAtLogin = LaunchManager.shared.isEnabled }
      .onChange(of: launchAtLogin) { _, newValue in
        let actual = LaunchManager.shared.setLaunchAtLogin(newValue)
        if actual != newValue { launchAtLogin = actual }
      }
    }
  }

  private var progress: some View {
    ZenLinearProgress(
      value: Double(step.rawValue + 1) / Double(OnboardingStep.allCases.count), height: 3
    )
    .zenAnimation(.standard, value: step)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
  }

  private var footer: some View {
    HStack {
      if let previous = step.previous {
        Button(action: { move(to: previous) }) {
          Text("Back")
        }
        .buttonStyle(.zenText)
        .accessibilityLabel("Go back")
      }

      Spacer()

      Button(action: advance) {
        Text(step.isLast ? "Start focusing" : "Continue")
      }
      .buttonStyle(.zenFilled)
      .keyboardShortcut(.defaultAction)
    }
  }

  private func move(to destination: OnboardingStep) {
    withZenAnimation(.standard, reduceMotion: reduceMotion) { step = destination }
  }

  private func advance() {
    guard let next = step.next else {
      LaunchManager.shared.setLaunchAtLogin(launchAtLogin)
      hasCompletedOnboarding = true
      return
    }
    move(to: next)
  }

  private func stepHeading(_ title: String, _ subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xs) {
      Text(title)
        .font(ZenFont.onboardingTitle)
        .foregroundStyle(ZenColor.onSurface)
        .accessibilityAddTraits(.isHeader)
      Text(subtitle)
        .font(ZenFont.bodyMedium)
        .foregroundStyle(ZenColor.onSurfaceVariant)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func difficultyBlurb(_ difficulty: BreakDifficulty) -> String {
    switch difficulty {
    case .casual:
      return String(
        localized: "Skip breaks anytime. They are friendly suggestions.", comment: "Onboarding difficulty blurb")
    case .balanced:
      return String(
        localized: "A short wait before you can skip. The recommended balance.", comment: "Onboarding difficulty blurb")
    case .hardcore:
      return String(localized: "No skips. Commit fully to every break.", comment: "Onboarding difficulty blurb")
    }
  }

  private func difficultyIcon(_ difficulty: BreakDifficulty) -> String {
    switch difficulty {
    case .casual: return "leaf.fill"
    case .balanced: return "hourglass"
    case .hardcore: return "lock.fill"
    }
  }
}
