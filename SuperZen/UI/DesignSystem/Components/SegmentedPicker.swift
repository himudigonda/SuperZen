import SwiftUI

struct ZenSegmentedPicker<Value: Hashable>: View {
  private let label: String
  @Binding private var selection: Value
  private let options: [Value]
  private let title: (Value) -> String
  private let systemImage: ((Value) -> String)?

  init(
    _ label: String,
    selection: Binding<Value>,
    options: [Value],
    title: @escaping (Value) -> String,
    systemImage: ((Value) -> String)? = nil
  ) {
    self.label = label
    self._selection = selection
    self.options = options
    self.title = title
    self.systemImage = systemImage
  }

  var body: some View {
    HStack(spacing: ZenSpacing.xxs) {
      ForEach(options, id: \.self) { option in
        ZenSegment(
          title: title(option),
          systemImage: systemImage?(option),
          isSelected: option == selection
        ) {
          selection = option
        }
      }
    }
    .padding(ZenSpacing.xxs)
    .fixedSize(horizontal: false, vertical: true)
    .background(ZenColor.surfaceContainerHigh, in: Capsule(style: .circular))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(label)
  }
}

private struct ZenSegment: View {
  let title: String
  let systemImage: String?
  let isSelected: Bool
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
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
      .padding(.horizontal, ZenSpacing.md)
      .frame(maxWidth: .infinity, minHeight: 32)
      .background(
        isSelected ? AnyShapeStyle(ZenColor.secondaryContainer) : AnyShapeStyle(Color.clear),
        in: Capsule(style: .circular)
      )
      .overlay(
        Capsule(style: .circular).fill(ZenColor.onSurface).opacity(isHovered ? ZenStateLayer.hover : 0)
          .allowsHitTesting(false)
      )
      .zenFocusRing(Capsule(style: .circular))
      .contentShape(Capsule(style: .circular))
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .onHover { isHovered = $0 }
    .zenAnimation(.quick, value: isHovered)
    .zenAnimation(.quick, value: isSelected)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
