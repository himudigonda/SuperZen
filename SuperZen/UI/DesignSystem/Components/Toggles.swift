import SwiftUI

struct ZenSwitchStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    ZenSwitchBody(configuration: configuration)
  }
}

private struct ZenSwitchBody: View {
  let configuration: ToggleStyleConfiguration
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.isFocused) private var isFocused
  @State private var isHovered = false
  @State private var isPressed = false

  private static let width: CGFloat = 52
  private static let height: CGFloat = 32

  var body: some View {
    let isOn = configuration.isOn
    Button {
      configuration.isOn.toggle()
    } label: {
      ZStack(alignment: isOn ? .trailing : .leading) {
        Capsule(style: .circular).fill(trackFill)
        Capsule(style: .circular).strokeBorder(trackStroke, lineWidth: 2)
        Circle()
          .fill(thumbFill)
          .frame(width: thumbSize, height: thumbSize)
          .overlay {
            if isOn {
              Image(systemName: "checkmark")
                .font(ZenFont.labelSmall)
                .foregroundStyle(checkFill)
                .accessibilityHidden(true)
            }
          }
          .padding(.horizontal, (Self.height - thumbSize) / 2)
          .background {
            Circle()
              .fill(isOn ? AnyShapeStyle(ZenColor.primary) : AnyShapeStyle(ZenColor.onSurface))
              .frame(width: 40, height: 40)
              .opacity(isEnabled ? ZenStateLayer.opacity(isHovered: isHovered, isPressed: isPressed) : 0)
              .allowsHitTesting(false)
              .padding(.horizontal, (Self.height - thumbSize) / 2)
          }
      }
      .frame(width: Self.width, height: Self.height)
      .overlay {
        if isFocused {
          Capsule(style: .circular).inset(by: -3).strokeBorder(ZenColor.secondary, lineWidth: 2)
        }
      }
      .contentShape(Capsule(style: .circular))
    }
    .buttonStyle(ZenPressReportingStyle(isPressed: $isPressed))
    .focusEffectDisabled()
    .onHover { isHovered = $0 }
    .zenAnimation(.emphasized, value: isOn)
    .zenAnimation(.quick, value: isPressed)
    .accessibilityRepresentation {
      Toggle(isOn: configuration.$isOn) { configuration.label }
        .toggleStyle(.switch)
    }
  }

  private var thumbSize: CGFloat {
    if isPressed { return 28 }
    return configuration.isOn ? 24 : 16
  }

  private var trackFill: AnyShapeStyle {
    if !isEnabled {
      return configuration.isOn
        ? AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContainer))
        : AnyShapeStyle(ZenColor.surfaceContainerHighest.opacity(ZenStateLayer.disabledContainer))
    }
    return configuration.isOn ? AnyShapeStyle(ZenColor.primary) : AnyShapeStyle(ZenColor.surfaceContainerHighest)
  }

  private var trackStroke: AnyShapeStyle {
    if configuration.isOn { return AnyShapeStyle(Color.clear) }
    return isEnabled
      ? AnyShapeStyle(ZenColor.outline) : AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContainer))
  }

  private var thumbFill: AnyShapeStyle {
    if !isEnabled {
      return configuration.isOn
        ? AnyShapeStyle(ZenColor.surface) : AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContent))
    }
    return configuration.isOn ? AnyShapeStyle(ZenColor.onPrimary) : AnyShapeStyle(ZenColor.outline)
  }

  private var checkFill: AnyShapeStyle {
    isEnabled
      ? AnyShapeStyle(ZenColor.primary) : AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContent))
  }
}

private struct ZenPressReportingStyle: ButtonStyle {
  @Binding var isPressed: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .onChange(of: configuration.isPressed) { _, pressed in isPressed = pressed }
  }
}

struct ZenCheckboxStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    ZenCheckboxBody(configuration: configuration)
  }
}

private struct ZenCheckboxBody: View {
  let configuration: ToggleStyleConfiguration
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      HStack(spacing: ZenSpacing.sm) {
        ZStack {
          RoundedRectangle(cornerRadius: ZenRadius.xs / 2, style: .continuous)
            .fill(configuration.isOn ? AnyShapeStyle(ZenColor.primary) : AnyShapeStyle(Color.clear))
          RoundedRectangle(cornerRadius: ZenRadius.xs / 2, style: .continuous)
            .strokeBorder(
              configuration.isOn ? AnyShapeStyle(Color.clear) : AnyShapeStyle(ZenColor.onSurfaceVariant), lineWidth: 2)
          if configuration.isOn {
            Image(systemName: "checkmark")
              .font(ZenFont.labelSmall)
              .foregroundStyle(ZenColor.onPrimary)
              .accessibilityHidden(true)
          }
        }
        .frame(width: 18, height: 18)
        .background {
          Circle().fill(ZenColor.onSurface).frame(width: 40, height: 40)
            .opacity(isHovered && isEnabled ? ZenStateLayer.hover : 0)
        }
        configuration.label
          .font(ZenFont.bodyMedium)
          .foregroundStyle(ZenColor.onSurface)
      }
      .contentShape(Rectangle())
      .opacity(isEnabled ? 1 : ZenStateLayer.disabledContent)
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .accessibilityRepresentation {
      Toggle(isOn: configuration.$isOn) { configuration.label }
        .toggleStyle(.checkbox)
    }
  }
}

extension ToggleStyle where Self == ZenSwitchStyle {
  static var zenSwitch: ZenSwitchStyle { ZenSwitchStyle() }
}

extension ToggleStyle where Self == ZenCheckboxStyle {
  static var zenCheckbox: ZenCheckboxStyle { ZenCheckboxStyle() }
}
