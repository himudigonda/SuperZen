import SuperZenCore
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
  case welcome
  case rule
  case rhythm
  case intensity
  case finish

  var id: Int { rawValue }
  var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
  var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
  var isFirst: Bool { previous == nil }
  var isLast: Bool { next == nil }
}

struct TwentyRuleFact: Identifiable, Equatable {
  let value: String
  let unit: String
  let caption: String
  let symbol: String

  var id: String { symbol }

  static func all(work: TimeInterval, rest: TimeInterval) -> [TwentyRuleFact] {
    [
      TwentyRuleFact(
        value: "\(Int(work / 60))",
        unit: String(localized: "minutes", comment: "20-20-20 rule unit"),
        caption: String(localized: "of focused screen time", comment: "20-20-20 rule caption"),
        symbol: "desktopcomputer"),
      TwentyRuleFact(
        value: "20",
        unit: String(localized: "feet", comment: "20-20-20 rule unit"),
        caption: String(localized: "look about 6 metres away", comment: "20-20-20 rule caption"),
        symbol: "binoculars.fill"),
      TwentyRuleFact(
        value: "\(Int(rest))",
        unit: String(localized: "seconds", comment: "20-20-20 rule unit"),
        caption: String(localized: "let your eyes relax", comment: "20-20-20 rule caption"),
        symbol: "eye"),
    ]
  }
}

struct OnboardingView: View {
  @AppStorage(SettingKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
  @AppStorage(SettingKey.difficulty) private var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.workDuration) private var workDuration: Double = SettingsCatalog.workDurationDefault
  @AppStorage(SettingKey.launchAtLogin) private var launchAtLogin = false

  @State private var step = OnboardingStep.welcome
  private let ruleFacts = TwentyRuleFact.all(
    work: SettingsCatalog.workDurationDefault, rest: SettingsCatalog.breakDurationDefault)
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      ZenCanvasBackground()

      VStack(spacing: ZenSpacing.xl) {
        stepContent
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
          .transition(
            ZenTransition.slide(insertion: .trailing, removal: .leading, reduceMotion: reduceMotion)
          )
          .id(step)

        footer
      }
      .padding(ZenSpacing.xxxl)
    }
    .frame(minWidth: 720, idealWidth: 760, minHeight: 580, idealHeight: 620)
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
    VStack(spacing: ZenSpacing.xl) {
      heroIcon("eye.fill")
      VStack(spacing: ZenSpacing.sm) {
        Text("Welcome to SuperZen")
          .font(ZenFont.display)
          .foregroundStyle(ZenColor.textPrimary)
        Text("Healthy screen time, without having to think about it.")
          .font(ZenFont.title2)
          .foregroundStyle(ZenColor.textSecondary)
          .multilineTextAlignment(.center)
        Text(
          String(
            localized:
              "Long stretches at a screen strain your eyes, back and focus. SuperZen sits quietly in your menu bar and paces your day with short, well-timed breaks.",
            comment: "Onboarding welcome step body")
        )
        .font(ZenFont.body)
        .foregroundStyle(ZenColor.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 460)
        .padding(.top, ZenSpacing.xxs)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var ruleStep: some View {
    VStack(spacing: ZenSpacing.xl) {
      stepHeading(
        String(localized: "The 20-20-20 rule", comment: "Onboarding step title"),
        String(
          localized: "Eye care professionals recommend it to ease digital eye strain. SuperZen runs it for you.",
          comment: "Onboarding step subtitle"))
      HStack(spacing: ZenSpacing.md) {
        ForEach(ruleFacts) { RuleTile(fact: $0) }
      }
      .frame(maxWidth: 600)
      Text(
        String(
          localized: "Every 20 minutes, look at something 20 feet away for 20 seconds. That tiny pause lets the focusing muscles in your eyes unclench.",
          comment: "Onboarding 20-20-20 explanation")
      )
      .font(ZenFont.callout)
      .foregroundStyle(ZenColor.textSecondary)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 480)
    }
  }

  private var rhythmStep: some View {
    VStack(spacing: ZenSpacing.lg) {
      stepHeading(
        String(localized: "How a cycle feels", comment: "Onboarding step title"),
        String(localized: "Gentle by default, firm when it matters.", comment: "Onboarding step subtitle"))
      Card(padding: ZenSpacing.xxs) {
        SettingRow(
          String(localized: "A heads-up first", comment: "Onboarding feature row title"),
          subtitle: String(
            localized: "A small pill follows your cursor a few seconds before each break, so nothing jumps at you.",
            comment: "Onboarding feature row subtitle"),
          icon: "cursorarrow.motionlines")
        CardDivider()
        SettingRow(
          String(localized: "A short eye break", comment: "Onboarding feature row title"),
          subtitle: String(
            localized: "The screen softens for \(DurationFormat.compact(SettingsCatalog.breakDurationDefault)). Look away and let your eyes rest.",
            comment: "Onboarding feature row subtitle with the eye break length"),
          icon: "eye.slash")
        CardDivider()
        SettingRow(
          String(localized: "A longer reset", comment: "Onboarding feature row title"),
          subtitle: String(
            localized:
              "Every \(SettingsCatalog.ordinal(SettingsCatalog.longBreakEveryDefault)) break lasts \(DurationFormat.compact(SettingsCatalog.longBreakDurationDefault)). Stand up, stretch, refill your water.",
            comment: "Onboarding feature row subtitle with the long break cadence and length"),
          icon: "figure.walk")
        CardDivider()
        SettingRow(
          String(localized: "Respectful of your flow", comment: "Onboarding feature row title"),
          subtitle: String(
            localized:
              "Mid-sentence? SuperZen waits up to \(DurationFormat.compact(SettingsCatalog.typingDeferralCapDefault)) while you type. Stepping away counts as a break too.",
            comment: "Onboarding feature row subtitle with the typing cap"),
          icon: "keyboard")
      }
      .frame(maxWidth: 540)
    }
  }

  private var intensityStep: some View {
    VStack(spacing: ZenSpacing.lg) {
      stepHeading(
        String(localized: "Pick your intensity", comment: "Onboarding step title"),
        String(
          localized: "How strict should breaks be? You can change this anytime.",
          comment: "Onboarding step subtitle"))
      VStack(spacing: ZenSpacing.sm) {
        ForEach(BreakDifficulty.allCases) { difficulty in
          OnboardingChoiceCard(
            title: difficulty.displayName,
            subtitle: difficultyBlurb(difficulty),
            gradient: ZenPalette.difficultyGradient(difficulty),
            isSelected: difficultyRaw == difficulty.rawValue
          ) {
            difficultyRaw = difficulty.rawValue
          }
        }
      }
      .frame(maxWidth: 520)

      VStack(spacing: ZenSpacing.xs) {
        Text("Focus block length")
          .font(ZenFont.captionEmphasized)
          .foregroundStyle(ZenColor.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        HStack(spacing: ZenSpacing.xs) {
          ForEach(SettingsCatalog.workDurationOptions, id: \.1) { option in
            durationPill(OptionLabel.localized(option.0), value: option.1)
          }
        }
      }
      .frame(maxWidth: 520)
      .padding(.top, ZenSpacing.xxs)
    }
  }

  private var finishStep: some View {
    VStack(spacing: ZenSpacing.xl) {
      heroIcon("checkmark")
      VStack(spacing: ZenSpacing.sm) {
        Text("You're all set")
          .font(ZenFont.display)
          .foregroundStyle(ZenColor.textPrimary)
        Text("Your first 20 minutes start now. Find SuperZen in the menu bar, up top.")
          .font(ZenFont.title2)
          .foregroundStyle(ZenColor.textSecondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 460)
      }

      Card(padding: ZenSpacing.xxs) {
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
            comment: "Onboarding shortcut hint subtitle with the start break shortcut"),
          icon: "command")
      }
      .frame(maxWidth: 460)
      .onChange(of: launchAtLogin) { _, newValue in
        LaunchManager.shared.setLaunchAtLogin(newValue)
      }
    }
  }

  private var footer: some View {
    HStack {
      if let previous = step.previous {
        Button(action: { move(to: previous) }) {
          Text("Back")
            .font(ZenFont.bodyEmphasized)
            .foregroundStyle(ZenColor.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go back")
      }

      Spacer()

      HStack(spacing: ZenSpacing.xs) {
        ForEach(OnboardingStep.allCases) { candidate in
          Capsule()
            .fill(candidate == step ? AnyShapeStyle(ZenColor.accent) : AnyShapeStyle(ZenColor.textSecondary.opacity(0.25)))
            .frame(width: candidate == step ? ZenSpacing.xl : ZenSpacing.xs, height: ZenSpacing.xs)
            .zenAnimation(.standard, value: step)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")

      Spacer()

      Button(action: advance) {
        Text(step.isLast ? "Start focusing" : "Continue")
          .font(ZenFont.bodyEmphasized)
          .foregroundStyle(ZenColor.onAccent)
          .padding(.horizontal, ZenSpacing.xl)
          .padding(.vertical, ZenSpacing.sm)
          .background(Capsule().fill(ZenGradient.accent))
      }
      .buttonStyle(.plain)
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

  private func heroIcon(_ systemName: String) -> some View {
    ZStack {
      Circle()
        .fill(ZenGradient.accent)
        .frame(width: 104, height: 104)
        .zenElevation(.floating)
      Image(systemName: systemName)
        .font(ZenFont.heroIcon)
        .foregroundStyle(ZenColor.onAccent)
    }
    .accessibilityHidden(true)
  }

  private func stepHeading(_ title: String, _ subtitle: String) -> some View {
    VStack(spacing: ZenSpacing.xs) {
      Text(title)
        .font(ZenFont.title)
        .foregroundStyle(ZenColor.textPrimary)
        .accessibilityAddTraits(.isHeader)
      Text(subtitle)
        .font(ZenFont.callout)
        .foregroundStyle(ZenColor.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 520)
    }
    .padding(.bottom, ZenSpacing.xxs)
  }

  private func durationPill(_ label: String, value: Double) -> some View {
    let isSelected = abs(workDuration - value) < 0.5
    return Button(action: { workDuration = value }) {
      Text(label)
        .font(ZenFont.bodyEmphasized)
        .foregroundStyle(isSelected ? ZenColor.onAccent : ZenColor.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, ZenSpacing.xs)
        .background(
          Capsule().fill(
            isSelected ? AnyShapeStyle(ZenGradient.accent) : AnyShapeStyle(.thinMaterial))
        )
        .overlay(Capsule().strokeBorder(ZenColor.controlStroke, lineWidth: isSelected ? 0 : 1))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(label) focus blocks")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  private func difficultyBlurb(_ difficulty: BreakDifficulty) -> String {
    switch difficulty {
    case .casual: return String(localized: "Skip breaks anytime. They are friendly suggestions.", comment: "Onboarding difficulty blurb")
    case .balanced: return String(localized: "A short wait before you can skip. The recommended balance.", comment: "Onboarding difficulty blurb")
    case .hardcore: return String(localized: "No skips. Commit fully to every break.", comment: "Onboarding difficulty blurb")
    }
  }
}

private struct RuleTile: View {
  let fact: TwentyRuleFact

  var body: some View {
    VStack(spacing: ZenSpacing.xs) {
      Image(systemName: fact.symbol)
        .font(ZenFont.rowIcon)
        .foregroundStyle(ZenColor.accent)
      HStack(alignment: .firstTextBaseline, spacing: ZenSpacing.xxs) {
        Text(fact.value)
          .font(ZenFont.display)
          .foregroundStyle(ZenColor.textPrimary)
        Text(fact.unit)
          .font(ZenFont.subheadlineEmphasized)
          .foregroundStyle(ZenColor.textSecondary)
      }
      Text(fact.caption)
        .font(ZenFont.caption)
        .foregroundStyle(ZenColor.textSecondary)
        .multilineTextAlignment(.center)
    }
    .padding(ZenSpacing.lg)
    .frame(maxWidth: .infinity)
    .zenSurface(cornerRadius: ZenRadius.lg)
    .accessibilityElement(children: .combine)
  }
}

private struct OnboardingChoiceCard: View {
  let title: String
  let subtitle: String
  let gradient: LinearGradient
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: ZenSpacing.md) {
        RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous)
          .fill(gradient)
          .frame(width: 36, height: 36)
          .opacity(isSelected ? 1 : 0.55)

        VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
          Text(title)
            .font(ZenFont.bodyEmphasized)
            .foregroundStyle(ZenColor.textPrimary)
          Text(subtitle)
            .font(ZenFont.subheadline)
            .foregroundStyle(ZenColor.textSecondary)
            .multilineTextAlignment(.leading)
        }

        Spacer()

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(ZenFont.rowIcon)
          .foregroundStyle(isSelected ? AnyShapeStyle(ZenColor.accent) : AnyShapeStyle(ZenColor.textSecondary.opacity(0.4)))
      }
      .padding(ZenSpacing.md)
      .zenSurface(cornerRadius: ZenRadius.md, elevation: .flat, isSelected: isSelected)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title) intensity. \(subtitle)")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}
