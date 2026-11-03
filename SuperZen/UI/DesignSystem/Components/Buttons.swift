import SwiftUI

nonisolated enum ZenButtonKind: Sendable {
  case filled
  case tonal
  case outlined
  case text
  case elevated
  case destructive
  case overlay
}

nonisolated enum ZenButtonSize: Sendable {
  case small
  case medium
  case large

  var height: CGFloat {
    switch self {
    case .small: return 32
    case .medium: return 40
    case .large: return 56
    }
  }

  var horizontalPadding: CGFloat {
    switch self {
    case .small: return ZenSpacing.sm
    case .medium: return ZenSpacing.xl
    case .large: return ZenSpacing.xxl
    }
  }

  var font: Font {
    self == .large ? ZenFont.titleMedium : ZenFont.labelLarge
  }
}

struct ZenButtonStyle: ButtonStyle {
  var kind: ZenButtonKind = .filled
  var size: ZenButtonSize = .medium
  var fillsWidth = false

  func makeBody(configuration: Configuration) -> some View {
    ZenButtonBody(configuration: configuration, kind: kind, size: size, fillsWidth: fillsWidth)
  }
}

private struct ZenButtonLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: ZenSpacing.xs) {
      configuration.icon
      configuration.title
    }
  }
}

private struct ZenButtonBody: View {
  let configuration: ButtonStyleConfiguration
  let kind: ZenButtonKind
  let size: ZenButtonSize
  let fillsWidth: Bool
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.isFocused) private var isFocused
  @State private var isHovered = false

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: configuration.isPressed ? ZenRadius.md : size.height / 2, style: .circular)
  }

  var body: some View {
    configuration.label
      .labelStyle(ZenButtonLabelStyle())
      .font(size.font)
      .lineLimit(1)
      .foregroundStyle(foreground)
      .padding(.horizontal, size.horizontalPadding)
      .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: size.height)
      .background {
        shape.fill(container)
        shape.fill(foreground)
          .opacity(isEnabled ? ZenStateLayer.opacity(isHovered: isHovered, isPressed: configuration.isPressed) : 0)
      }
      .overlay {
        if kind == .outlined || kind == .overlay {
          shape.strokeBorder(outlineStyle, lineWidth: 1)
        }
      }
      .overlay {
        if isFocused {
          shape.inset(by: -3).strokeBorder(ZenColor.secondary, lineWidth: 2)
        }
      }
      .contentShape(shape)
      .zenElevation(kind == .elevated && isEnabled ? .level1 : .level0)
      .focusEffectDisabled()
      .onHover { isHovered = $0 }
      .zenAnimation(.quick, value: isHovered)
      .zenAnimation(.quick, value: configuration.isPressed)
  }

  private var outlineStyle: AnyShapeStyle {
    if kind == .overlay { return AnyShapeStyle(ZenColor.overlayStroke) }
    return isEnabled
      ? AnyShapeStyle(ZenColor.outline) : AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContainer))
  }

  private var container: AnyShapeStyle {
    guard isEnabled else {
      switch kind {
      case .outlined, .text: return AnyShapeStyle(Color.clear)
      case .overlay: return AnyShapeStyle(ZenColor.overlaySurface)
      default: return AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContainer))
      }
    }
    switch kind {
    case .filled: return AnyShapeStyle(ZenColor.primary)
    case .tonal: return AnyShapeStyle(ZenColor.secondaryContainer)
    case .outlined, .text: return AnyShapeStyle(Color.clear)
    case .elevated: return AnyShapeStyle(ZenColor.surfaceContainerLow)
    case .destructive: return AnyShapeStyle(ZenColor.error)
    case .overlay: return AnyShapeStyle(ZenColor.overlaySurface)
    }
  }

  private var foreground: AnyShapeStyle {
    guard isEnabled else {
      return kind == .overlay
        ? AnyShapeStyle(ZenColor.overlayTextSecondary)
        : AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContent))
    }
    switch kind {
    case .filled: return AnyShapeStyle(ZenColor.onPrimary)
    case .tonal: return AnyShapeStyle(ZenColor.onSecondaryContainer)
    case .outlined, .text, .elevated: return AnyShapeStyle(ZenColor.primary)
    case .destructive: return AnyShapeStyle(ZenColor.onError)
    case .overlay: return AnyShapeStyle(ZenColor.overlayText)
    }
  }
}

nonisolated enum ZenIconButtonKind: Sendable {
  case standard
  case filled
  case tonal
  case outlined
  case overlay
}

struct ZenIconButtonStyle: ButtonStyle {
  var kind: ZenIconButtonKind = .standard
  var size: CGFloat = 40
  var isSelected = false

  func makeBody(configuration: Configuration) -> some View {
    ZenIconButtonBody(configuration: configuration, kind: kind, size: size, isSelected: isSelected)
  }
}

private struct ZenIconButtonBody: View {
  let configuration: ButtonStyleConfiguration
  let kind: ZenIconButtonKind
  let size: CGFloat
  let isSelected: Bool
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.isFocused) private var isFocused
  @State private var isHovered = false

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: configuration.isPressed ? ZenRadius.md : size / 2, style: .circular)
  }

  var body: some View {
    configuration.label
      .font(size >= 40 ? ZenFont.iconMedium : ZenFont.iconSmall)
      .foregroundStyle(foreground)
      .frame(width: size, height: size)
      .background {
        shape.fill(container)
        shape.fill(foreground)
          .opacity(isEnabled ? ZenStateLayer.opacity(isHovered: isHovered, isPressed: configuration.isPressed) : 0)
      }
      .overlay {
        if kind == .outlined {
          shape.strokeBorder(ZenColor.outline, lineWidth: 1)
        }
      }
      .overlay {
        if isFocused {
          shape.inset(by: -3).strokeBorder(ZenColor.secondary, lineWidth: 2)
        }
      }
      .contentShape(shape)
      .focusEffectDisabled()
      .onHover { isHovered = $0 }
      .zenAnimation(.quick, value: isHovered)
      .zenAnimation(.quick, value: configuration.isPressed)
  }

  private var container: AnyShapeStyle {
    guard isEnabled else {
      return kind == .standard
        ? AnyShapeStyle(Color.clear) : AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContainer))
    }
    if isSelected { return AnyShapeStyle(ZenColor.primary) }
    switch kind {
    case .standard, .outlined: return AnyShapeStyle(Color.clear)
    case .filled: return AnyShapeStyle(ZenColor.primary)
    case .tonal: return AnyShapeStyle(ZenColor.secondaryContainer)
    case .overlay: return AnyShapeStyle(ZenColor.overlaySurface)
    }
  }

  private var foreground: AnyShapeStyle {
    guard isEnabled else { return AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContent)) }
    if isSelected { return AnyShapeStyle(ZenColor.onPrimary) }
    switch kind {
    case .standard, .outlined: return AnyShapeStyle(ZenColor.onSurfaceVariant)
    case .filled: return AnyShapeStyle(ZenColor.onPrimary)
    case .tonal: return AnyShapeStyle(ZenColor.onSecondaryContainer)
    case .overlay: return AnyShapeStyle(ZenColor.overlayText)
    }
  }
}

struct ZenCardButtonStyle: ButtonStyle {
  var cornerRadius: CGFloat = ZenRadius.lg

  func makeBody(configuration: Configuration) -> some View {
    ZenCardButtonBody(configuration: configuration, cornerRadius: cornerRadius)
  }
}

private struct ZenCardButtonBody: View {
  let configuration: ButtonStyleConfiguration
  let cornerRadius: CGFloat
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.isFocused) private var isFocused
  @State private var isHovered = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    configuration.label
      .overlay {
        shape.fill(ZenColor.onSurface)
          .opacity(isEnabled ? ZenStateLayer.opacity(isHovered: isHovered, isPressed: configuration.isPressed) : 0)
          .allowsHitTesting(false)
      }
      .overlay {
        if isFocused {
          shape.inset(by: -3).strokeBorder(ZenColor.secondary, lineWidth: 2)
        }
      }
      .contentShape(shape)
      .opacity(isEnabled ? 1 : ZenStateLayer.disabledContent)
      .focusEffectDisabled()
      .onHover { isHovered = $0 }
      .zenAnimation(.quick, value: isHovered)
  }
}

extension ButtonStyle where Self == ZenButtonStyle {
  static var zenFilled: ZenButtonStyle { ZenButtonStyle(kind: .filled) }
  static var zenTonal: ZenButtonStyle { ZenButtonStyle(kind: .tonal) }
  static var zenOutlined: ZenButtonStyle { ZenButtonStyle(kind: .outlined) }
  static var zenText: ZenButtonStyle { ZenButtonStyle(kind: .text) }
  static var zenElevated: ZenButtonStyle { ZenButtonStyle(kind: .elevated) }
  static var zenDestructive: ZenButtonStyle { ZenButtonStyle(kind: .destructive) }
  static var zenOverlay: ZenButtonStyle { ZenButtonStyle(kind: .overlay) }
}

extension ButtonStyle where Self == ZenIconButtonStyle {
  static var zenIcon: ZenIconButtonStyle { ZenIconButtonStyle(kind: .standard) }
  static var zenIconFilled: ZenIconButtonStyle { ZenIconButtonStyle(kind: .filled) }
  static var zenIconTonal: ZenIconButtonStyle { ZenIconButtonStyle(kind: .tonal) }
  static var zenIconOutlined: ZenIconButtonStyle { ZenIconButtonStyle(kind: .outlined) }
}

extension ButtonStyle where Self == ZenCardButtonStyle {
  static var zenCard: ZenCardButtonStyle { ZenCardButtonStyle() }
}
