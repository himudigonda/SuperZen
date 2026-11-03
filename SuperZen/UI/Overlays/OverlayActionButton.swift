import SwiftUI

struct OverlayActionStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    OverlayActionBody(configuration: configuration)
  }
}

private struct OverlayActionBody: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.isFocused) private var isFocused
  @Environment(\.zenTheme) private var theme
  @State private var isHovered = false

  private var shape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: configuration.isPressed ? ZenRadius.md : ZenOverlayMetrics.actionHeight / 2,
      style: .circular)
  }

  var body: some View {
    configuration.label
      .labelStyle(OverlayActionLabelStyle())
      .font(ZenFont.overlayAction)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .foregroundStyle(isEnabled ? ZenColor.overlayText : ZenColor.overlayTextSecondary)
      .padding(.horizontal, ZenSpacing.xl)
      .frame(minWidth: ZenOverlayMetrics.actionMinWidth, minHeight: ZenOverlayMetrics.actionHeight)
      .background {
        shape.fill(ZenColor.overlayControl)
        shape.fill(ZenColor.overlayText)
          .opacity(isEnabled ? ZenStateLayer.opacity(isHovered: isHovered, isPressed: configuration.isPressed) : 0)
      }
      .overlay {
        shape.strokeBorder(ZenColor.overlayStroke, lineWidth: theme.contrast == .high ? 2 : 1)
      }
      .overlay {
        if isFocused {
          shape.inset(by: -4).strokeBorder(ZenColor.overlayText, lineWidth: 2)
        }
      }
      .contentShape(shape)
      .opacity(isEnabled ? 1 : ZenOverlayMetrics.disabledOpacity)
      .focusEffectDisabled()
      .onHover { isHovered = $0 }
      .zenAnimation(.quick, value: isHovered)
      .zenAnimation(.quick, value: configuration.isPressed)
  }
}

private struct OverlayActionLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: ZenSpacing.xs) {
      configuration.icon
      configuration.title
    }
  }
}

struct OverlayActionButton: View {
  let icon: String
  let title: LocalizedStringKey
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: icon)
    }
    .buttonStyle(OverlayActionStyle())
  }
}
