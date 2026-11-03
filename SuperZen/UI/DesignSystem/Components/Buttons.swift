import SwiftUI

nonisolated enum ZenControlProminence: Sendable {
  case standard
  case accent
  case danger
}

struct ZenControlButtonStyle: ButtonStyle {
  var prominence: ZenControlProminence = .standard
  var cornerRadius: CGFloat = ZenRadius.sm
  var isCircular = false

  func makeBody(configuration: Configuration) -> some View {
    ZenControlButtonBody(
      configuration: configuration, prominence: prominence, cornerRadius: cornerRadius,
      isCircular: isCircular)
  }
}

private struct ZenControlButtonBody: View {
  let configuration: ButtonStyleConfiguration
  let prominence: ZenControlProminence
  let cornerRadius: CGFloat
  let isCircular: Bool
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    let shape = RoundedRectangle(
      cornerRadius: isCircular ? .greatestFiniteMagnitude : cornerRadius,
      style: isCircular ? .circular : .continuous)
    configuration.label
      .foregroundStyle(foreground)
      .background {
        if isEnabled {
          shape.fill(fill)
          shape.fill(ZenColor.textPrimary.opacity(interactionOpacity))
        }
      }
      .overlay {
        if prominence == .standard || !isEnabled {
          shape.strokeBorder(isEnabled ? ZenColor.controlStroke : ZenColor.divider, lineWidth: 1)
        }
      }
      .contentShape(shape)
      .onHover { isHovered = $0 }
      .zenAnimation(.quick, value: isHovered)
  }

  private var interactionOpacity: Double {
    if configuration.isPressed { return 0.14 }
    return isHovered ? 0.07 : 0
  }

  private var fill: AnyShapeStyle {
    switch prominence {
    case .standard: return AnyShapeStyle(ZenGradient.surface)
    case .accent: return AnyShapeStyle(ZenColor.accent)
    case .danger: return AnyShapeStyle(ZenColor.danger)
    }
  }

  private var foreground: AnyShapeStyle {
    guard isEnabled else { return AnyShapeStyle(ZenColor.textTertiary.opacity(0.6)) }
    return prominence == .standard ? AnyShapeStyle(ZenColor.textPrimary) : AnyShapeStyle(ZenColor.onAccent)
  }
}

struct ZenQuietButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    ZenQuietButtonBody(configuration: configuration)
  }
}

private struct ZenQuietButtonBody: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.xs, style: .continuous)
    configuration.label
      .padding(.horizontal, ZenSpacing.xs)
      .padding(.vertical, ZenSpacing.xxs)
      .foregroundStyle(isHovered && isEnabled ? ZenColor.textPrimary : ZenColor.textSecondary)
      .background(shape.fill(ZenColor.textPrimary.opacity(interactionOpacity)))
      .contentShape(shape)
      .onHover { isHovered = $0 }
      .zenAnimation(.quick, value: isHovered)
  }

  private var interactionOpacity: Double {
    guard isEnabled else { return 0 }
    if configuration.isPressed { return 0.14 }
    return isHovered ? 0.07 : 0
  }
}

struct ZenCardButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    ZenCardButtonBody(configuration: configuration)
  }
}

private struct ZenCardButtonBody: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    configuration.label
      .brightness(isHovered && isEnabled ? 0.04 : 0)
      .opacity(configuration.isPressed ? 0.75 : 1)
      .contentShape(Rectangle())
      .onHover { isHovered = $0 }
      .zenAnimation(.quick, value: isHovered)
  }
}
