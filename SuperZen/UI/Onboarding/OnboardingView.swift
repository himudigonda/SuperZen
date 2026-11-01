import SuperZenCore
import SwiftUI

struct OnboardingView: View {
  @AppStorage(SettingKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
  @AppStorage(SettingKey.difficulty) private var difficultyRaw = BreakDifficulty.balanced.rawValue
  @AppStorage(SettingKey.workDuration) private var workDuration: Double = SettingsCatalog
    .workDurationDefault
  @AppStorage(SettingKey.launchAtLogin) private var launchAtLogin = false

  @State private var step = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let totalSteps = 4

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
    .frame(minWidth: 720, idealWidth: 760, minHeight: 560, idealHeight: 600)
  }


  @ViewBuilder private var stepContent: some View {
    switch step {
    case 0: welcomeStep
    case 1: howItWorksStep
    case 2: styleStep
    default: finishStep
    }
  }

  private var welcomeStep: some View {
    VStack(spacing: ZenSpacing.xl) {
      heroIcon("eye.fill")
      VStack(spacing: ZenSpacing.sm) {
        Text("Welcome to SuperZen")
          .font(ZenFont.display)
          .foregroundStyle(ZenColor.textPrimary)
        Text("Your eyes and focus, looked after — automatically.")
          .font(ZenFont.title2)
          .foregroundStyle(ZenColor.textSecondary)
          .multilineTextAlignment(.center)
        Text(
          String(
            localized:
              "SuperZen lives in your menu bar and gently reminds you to rest your eyes, fix your posture, and take real breaks — following the 20-20-20 rule for healthy screen time.",
            comment: "Onboarding welcome step body")
        )
        .font(ZenFont.body)
        .foregroundStyle(ZenColor.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 440)
        .padding(.top, ZenSpacing.xxs)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var howItWorksStep: some View {
    VStack(spacing: ZenSpacing.lg) {
      stepHeading("How SuperZen helps", "Three quiet systems working in the background.")
      Card(padding: ZenSpacing.xxs) {
        SettingRow(
          String(localized: "Focus blocks & breaks", comment: "Onboarding feature row title"),
          subtitle: String(
            localized:
              "Work in focused blocks, then a full-screen break to actually rest your eyes.",
            comment: "Onboarding feature row subtitle"),
          icon: "timer")
        CardDivider()
        SettingRow(
          String(localized: "Gentle nudges", comment: "Onboarding feature row title"),
          subtitle: String(
            localized:
              "A small pill follows your cursor before a break — no jarring interruptions.",
            comment: "Onboarding feature row subtitle"),
          icon: "cursorarrow.motionlines")
        CardDivider()
        SettingRow(
          String(localized: "Wellness pulses", comment: "Onboarding feature row title"),
          subtitle: String(
            localized:
              "Quick posture, blink, hydration, and affirmation reminders through the day.",
            comment: "Onboarding feature row subtitle"),
          icon: "figure.mind.and.body")
      }
      .frame(maxWidth: 520)
    }
  }

  private var styleStep: some View {
    VStack(spacing: ZenSpacing.lg) {
      stepHeading(
        "Pick your intensity", "How strict should breaks be? You can change this anytime.")
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
            durationPill(option.0, value: option.1)
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
        Text("SuperZen is now watching out for you from the menu bar, up top ↗")
          .font(ZenFont.title2)
          .foregroundStyle(ZenColor.textSecondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 440)
      }

      Card(padding: ZenSpacing.xxs) {
        LabeledToggle(
          String(localized: "Open SuperZen at login", comment: "Onboarding launch at login toggle"),
          subtitle: String(
            localized:
              "Recommended — so your eyes are protected every day without thinking about it.",
            comment: "Onboarding launch at login toggle subtitle"),
          isOn: $launchAtLogin)
      }
      .frame(maxWidth: 440)
      .onChange(of: launchAtLogin) { _, newValue in
        LaunchManager.shared.setLaunchAtLogin(newValue)
      }
    }
  }


  private var footer: some View {
    HStack {
      if step > 0 {
        Button(action: { withZenAnimation(.standard, reduceMotion: reduceMotion) { step -= 1 } }) {
          Text("Back")
            .font(ZenFont.bodyEmphasized)
            .foregroundStyle(ZenColor.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go back")
      }

      Spacer()

      HStack(spacing: ZenSpacing.xs) {
        ForEach(0..<totalSteps, id: \.self) { index in
          Capsule()
            .fill(index == step ? AnyShapeStyle(ZenColor.accent) : AnyShapeStyle(ZenColor.textSecondary.opacity(0.25)))
            .frame(width: index == step ? ZenSpacing.xl : ZenSpacing.xs, height: ZenSpacing.xs)
            .zenAnimation(.standard, value: step)
        }
      }
      .accessibilityLabel("Step \(step + 1) of \(totalSteps)")

      Spacer()

      Button(action: advance) {
        Text(step == totalSteps - 1 ? "Start focusing" : "Continue")
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


  private func advance() {
    if step >= totalSteps - 1 {
      LaunchManager.shared.setLaunchAtLogin(launchAtLogin)
      hasCompletedOnboarding = true
    } else {
      withZenAnimation(.standard, reduceMotion: reduceMotion) { step += 1 }
    }
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
    case .casual: return "Skip breaks anytime — they're friendly suggestions."
    case .balanced: return "A short wait before you can skip. The recommended balance."
    case .hardcore: return "No skips. Commit fully to every break."
    }
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
