import SuperZenCore
import SwiftUI

struct OnboardingFeature: View {
  let icon: String
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: ZenSpacing.sm) {
      Image(systemName: icon)
        .font(ZenFont.bodyMedium)
        .foregroundStyle(ZenColor.primary)
        .frame(width: ZenSpacing.lg)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: ZenSpacing.xxs / 2) {
        Text(title)
          .font(ZenFont.labelLarge)
          .foregroundStyle(ZenColor.onSurface)
        Text(detail)
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

struct FocusLengthPicker: View {
  @Binding var value: Double
  let options: [(String, Double)]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var selectedLabel: String? {
    options.first { isSelected($0.1) }.map { OptionLabel.localized($0.0) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xs) {
      HStack(alignment: .firstTextBaseline) {
        Text("Focus block length")
          .font(ZenFont.labelLarge)
          .foregroundStyle(ZenColor.onSurface)
        Spacer()
        if let selectedLabel {
          Text(verbatim: selectedLabel)
            .font(ZenFont.bodyMedium)
            .foregroundStyle(ZenColor.onSurfaceVariant)
            .contentTransition(.numericText())
        }
      }

      HStack(spacing: ZenSpacing.xs) {
        ForEach(options, id: \.1) { option in
          segment(label: OptionLabel.localized(option.0), option: option.1)
        }
      }
    }
  }

  private func segment(label: String, option: Double) -> some View {
    let selected = isSelected(option)
    return ZenFilterChip(
      title: "\(Int(option / 60))",
      isSelected: selected,
      action: {
        withZenAnimation(.standard, reduceMotion: reduceMotion) { value = option }
      }
    )
    .accessibilityLabel("\(label) focus blocks")
    .accessibilityAddTraits(selected ? [.isSelected] : [])
  }

  private func isSelected(_ option: Double) -> Bool {
    abs(value - option) < 0.5
  }
}

struct OnboardingChoiceCard: View {
  let title: String
  let subtitle: String
  let icon: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: ZenSpacing.md) {
        Image(systemName: icon)
          .font(ZenFont.iconMedium)
          .foregroundStyle(isSelected ? AnyShapeStyle(ZenColor.primary) : AnyShapeStyle(ZenColor.onSurfaceVariant))
          .frame(width: ZenSpacing.xl)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: ZenSpacing.xxs / 2) {
          Text(title)
            .font(ZenFont.titleSmall)
            .foregroundStyle(ZenColor.onSurface)
          Text(subtitle)
            .font(ZenFont.bodySmall)
            .foregroundStyle(ZenColor.onSurfaceVariant)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)

        Image(systemName: "checkmark.circle.fill")
          .font(ZenFont.iconMedium)
          .foregroundStyle(ZenColor.primary)
          .opacity(isSelected ? 1 : 0)
          .accessibilityHidden(true)
      }
      .padding(.horizontal, ZenSpacing.md)
      .padding(.vertical, ZenSpacing.sm)
      .zenSurface(isSelected: isSelected)
    }
    .buttonStyle(.zenCard)
    .accessibilityLabel("\(title) intensity. \(subtitle)")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}
