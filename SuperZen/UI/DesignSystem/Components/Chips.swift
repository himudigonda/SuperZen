import SwiftUI

struct ZenFilterChip: View {
  let title: String
  let isSelected: Bool
  var systemImage: String?
  let action: () -> Void
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous)
    Button(action: action) {
      HStack(spacing: ZenSpacing.xs) {
        if isSelected {
          Image(systemName: "checkmark")
            .font(ZenFont.iconSmall)
            .accessibilityHidden(true)
        } else if let systemImage {
          Image(systemName: systemImage)
            .font(ZenFont.iconSmall)
            .accessibilityHidden(true)
        }
        Text(title)
          .font(ZenFont.labelLarge)
          .lineLimit(1)
      }
      .foregroundStyle(isSelected ? ZenColor.onSecondaryContainer : ZenColor.onSurfaceVariant)
      .padding(.horizontal, ZenSpacing.sm)
      .frame(minHeight: 32)
      .background(isSelected ? AnyShapeStyle(ZenColor.secondaryContainer) : AnyShapeStyle(Color.clear), in: shape)
      .overlay {
        if !isSelected {
          shape.strokeBorder(ZenColor.outlineVariant, lineWidth: 1)
        }
      }
      .overlay(
        shape.fill(ZenColor.onSurface).opacity(isHovered && isEnabled ? ZenStateLayer.hover : 0)
          .allowsHitTesting(false)
      )
      .zenFocusRing(shape)
      .contentShape(shape)
      .opacity(isEnabled ? 1 : ZenStateLayer.disabledContent)
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .onHover { isHovered = $0 }
    .zenAnimation(.quick, value: isHovered)
    .zenAnimation(.quick, value: isSelected)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

nonisolated enum ZenBadgeTone: Sendable {
  case neutral, primary, success, warning, error, info
}

struct ZenBadge: View {
  let text: String
  var tone: ZenBadgeTone = .neutral
  var systemImage: String?

  var body: some View {
    HStack(spacing: ZenSpacing.xxs) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(ZenFont.labelSmall)
          .accessibilityHidden(true)
      }
      Text(text)
        .font(ZenFont.labelMedium)
        .lineLimit(1)
    }
    .foregroundStyle(foreground)
    .padding(.horizontal, ZenSpacing.xs)
    .frame(minHeight: 24)
    .background(background, in: Capsule(style: .circular))
  }

  private var background: ZenColor {
    switch tone {
    case .neutral: return .surfaceContainerHighest
    case .primary: return .primaryContainer
    case .success: return .successContainer
    case .warning: return .warningContainer
    case .error: return .errorContainer
    case .info: return .infoContainer
    }
  }

  private var foreground: ZenColor {
    switch tone {
    case .neutral: return .onSurfaceVariant
    case .primary: return .onPrimaryContainer
    case .success: return .onSuccessContainer
    case .warning: return .onWarningContainer
    case .error: return .onErrorContainer
    case .info: return .onInfoContainer
    }
  }
}
