import SuperZenCore
import SwiftUI

struct OnboardingStage: View {
  let step: OnboardingStep
  let difficulty: BreakDifficulty
  let workDuration: Double

  var body: some View {
    ZStack {
      StageBackdrop()
      scene
        .id(step)
        .transition(.opacity)
    }
    .zenAnimation(.gentle, value: step)
    .environment(\.colorScheme, .dark)
    .accessibilityHidden(true)
  }

  @ViewBuilder private var scene: some View {
    switch step {
    case .welcome: EnsoScene()
    case .rule: RuleScene()
    case .rhythm: CycleScene(workDuration: workDuration)
    case .intensity: BreakPreviewScene(difficulty: difficulty)
    case .finish: MenuBarScene(workDuration: workDuration, difficulty: difficulty)
    }
  }
}

private struct StageBackdrop: View {
  @Environment(\.zenTheme) private var theme

  var body: some View {
    ZStack {
      ZenRGBA(rgb: 0x0A0D11).color
      RadialGradient(
        colors: [theme.rgba(.accent, scheme: .dark).withAlpha(0.28).color, .clear],
        center: .bottomLeading,
        startRadius: 0,
        endRadius: 520)
    }
  }
}

private struct EnsoScene: View {
  @State private var isBreathing = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.zenTheme) private var theme

  var body: some View {
    ZStack {
      Circle()
        .fill(theme.rgba(.accent, scheme: .dark).withAlpha(0.32).color)
        .frame(width: 200, height: 200)
        .blur(radius: 56)
        .scaleEffect(isBreathing ? 1.25 : 0.9)
      Circle()
        .strokeBorder(ZenColor.overlayText, lineWidth: 16)
        .frame(width: 180, height: 180)
        .scaleEffect(isBreathing ? 1.03 : 0.97)
    }
    .animation(
      reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true), value: isBreathing
    )
    .onAppear { isBreathing = !reduceMotion }
  }
}

private struct RuleScene: View {
  private let facts = TwentyRuleFact.all(
    work: SettingsCatalog.workDurationDefault, rest: SettingsCatalog.breakDurationDefault)

  @State private var active = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xl) {
      ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
        VStack(alignment: .leading, spacing: 0) {
          HStack(alignment: .firstTextBaseline, spacing: ZenSpacing.xs) {
            Text(verbatim: fact.value)
              .font(ZenFont.onboardingNumeral)
              .foregroundStyle(ZenColor.overlayText)
            Text(verbatim: fact.unit)
              .font(ZenFont.title2)
              .foregroundStyle(ZenColor.overlayText)
          }
          Text(verbatim: fact.caption)
            .font(ZenFont.callout)
            .foregroundStyle(ZenColor.overlayTextSecondary)
        }
        .opacity(reduceMotion || index == active ? 1 : 0.35)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, ZenSpacing.xxxl)
    .zenAnimation(.gentle, value: active)
    .task {
      guard !reduceMotion else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2.4))
        active = (active + 1) % facts.count
      }
    }
  }
}

private struct CycleScene: View {
  let workDuration: Double

  private var segments: [OnboardingCycleSegment] {
    OnboardingCycleSegment.cycle(
      work: workDuration,
      rest: SettingsCatalog.breakDurationDefault,
      longRest: SettingsCatalog.longBreakDurationDefault,
      longEvery: SettingsCatalog.longBreakEveryDefault)
  }

  private var focusHeight: CGFloat {
    let shortest = 1200.0
    let longest = 5400.0
    let progress = min(1, max(0, (workDuration - shortest) / (longest - shortest)))
    return 36 + CGFloat(progress) * 52
  }

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.md) {
      HStack(alignment: .firstTextBaseline) {
        Text("One full cycle")
          .font(ZenFont.calloutEmphasized)
          .foregroundStyle(ZenColor.overlayText)
        Spacer()
        Text(verbatim: DurationFormat.compact(segments.reduce(0) { $0 + $1.duration }))
          .font(ZenFont.callout.monospacedDigit())
          .foregroundStyle(ZenColor.overlayTextSecondary)
          .contentTransition(.numericText())
      }

      VStack(spacing: ZenSpacing.xxs) {
        ForEach(segments) { segment in
          row(for: segment)
        }
      }
    }
    .padding(.horizontal, ZenSpacing.xxl)
    .zenAnimation(.standard, value: workDuration)
  }

  @ViewBuilder private func row(for segment: OnboardingCycleSegment) -> some View {
    switch segment.kind {
    case .focus:
      label("Focus", segment.duration, font: ZenFont.calloutEmphasized)
        .frame(height: focusHeight)
        .background(
          RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous).fill(.white.opacity(0.1)))
    case .eyeBreak:
      label("Eye break", segment.duration, font: ZenFont.caption)
        .frame(height: ZenSpacing.lg)
        .opacity(0.72)
    case .longBreak:
      label("Long break", segment.duration, font: ZenFont.calloutEmphasized)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous).fill(ZenColor.accent))
    }
  }

  private func label(_ title: LocalizedStringKey, _ duration: TimeInterval, font: Font) -> some View {
    HStack {
      Text(title)
      Spacer()
      Text(verbatim: DurationFormat.compact(duration))
        .monospacedDigit()
        .contentTransition(.numericText())
    }
    .font(font)
    .foregroundStyle(ZenColor.overlayText)
    .padding(.horizontal, ZenSpacing.sm)
  }
}

private struct BreakPreviewScene: View {
  let difficulty: BreakDifficulty

  @State private var elapsed = 0

  private let breakLength = Int(SettingsCatalog.breakDurationDefault)

  private var skipState: OnboardingSkipState {
    OnboardingSkipState(
      difficulty: difficulty,
      elapsed: TimeInterval(elapsed),
      lock: SkipPolicy().lockDuration(forBreakOf: SettingsCatalog.breakDurationDefault))
  }

  var body: some View {
    ZStack {
      MeshGradient(
        width: 3, height: 3,
        points: [
          [0, 0], [0.5, 0], [1, 0],
          [0, 0.5], [0.8, 0.2], [1, 0.5],
          [0, 1], [0.5, 1], [1, 1],
        ],
        colors: ZenPalette.breakAtmosphere(difficulty, canSkip: skipState.canSkip)
      )
      .zenAnimation(.ambient, value: skipState.canSkip)
      .zenAnimation(.ambient, value: difficulty)

      Color.black.opacity(0.45)

      VStack(spacing: ZenSpacing.lg) {
        Text("Take a moment to breathe")
          .font(ZenFont.title)
          .foregroundStyle(ZenColor.overlayText)
          .multilineTextAlignment(.center)

        Text(verbatim: String(format: "00:%02d", breakLength - elapsed))
          .font(ZenFont.onboardingNumeral)
          .foregroundStyle(ZenColor.overlayText)
          .contentTransition(.numericText(countsDown: true))

        skipPill
      }
      .padding(.horizontal, ZenSpacing.xl)
    }
    .task(id: difficulty) {
      elapsed = 0
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        withAnimation(.snappy) { elapsed = (elapsed + 1) % breakLength }
      }
    }
  }

  private var skipPill: some View {
    HStack(spacing: ZenSpacing.xs) {
      Group {
        switch skipState {
        case .available: Image(systemName: "forward.end.fill")
        case .locked: Image(systemName: "hourglass")
        case .forbidden: Image(systemName: "nosign")
        }
      }
      .foregroundStyle(ZenPalette.breakAccent(difficulty, canSkip: skipState.canSkip))

      switch skipState {
      case .available: Text("Skip Break")
      case .locked(let seconds): Text("Wait \(seconds)s")
      case .forbidden: Text("No skips allowed")
      }
    }
    .font(ZenFont.roundedLabel.monospacedDigit())
    .foregroundStyle(ZenColor.overlayText)
    .padding(.horizontal, ZenSpacing.lg)
    .padding(.vertical, ZenSpacing.sm)
    .background(ZenColor.overlaySurface, in: Capsule())
    .overlay(Capsule().strokeBorder(ZenColor.overlayStroke, lineWidth: 1))
  }
}

private struct MenuBarScene: View {
  let workDuration: Double
  let difficulty: BreakDifficulty

  @State private var isPulsing = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .trailing, spacing: ZenSpacing.sm) {
      HStack(spacing: ZenSpacing.sm) {
        Image(systemName: MenuBarGlyph.focusing.symbolName)
          .foregroundStyle(ZenColor.overlayText)
          .padding(ZenSpacing.xxs)
          .background(
            Circle()
              .fill(ZenColor.accent.opacity(isPulsing ? 0.75 : 0.35))
          )
        Image(systemName: "wifi")
        Image(systemName: "battery.100percent")
        Text(verbatim: "9:41")
      }
      .font(ZenFont.callout)
      .foregroundStyle(ZenColor.overlayTextSecondary)
      .padding(.horizontal, ZenSpacing.sm)
      .padding(.vertical, ZenSpacing.xxs)
      .frame(maxWidth: .infinity, alignment: .trailing)
      .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous))

      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        Text(verbatim: MenuBarGlyph.focusing.title)
          .font(ZenFont.calloutEmphasized)
          .foregroundStyle(ZenColor.overlayTextSecondary)
        Text(verbatim: DurationFormat.compact(workDuration))
          .font(ZenFont.onboardingNumeral)
          .foregroundStyle(ZenColor.overlayText)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
        Text(verbatim: difficulty.displayName)
          .font(ZenFont.callout)
          .foregroundStyle(ZenColor.overlayTextSecondary)
      }
      .padding(ZenSpacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: ZenRadius.lg, style: .continuous))
    }
    .padding(.horizontal, ZenSpacing.xxl)
    .animation(
      reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: isPulsing
    )
    .onAppear { isPulsing = !reduceMotion }
  }
}
