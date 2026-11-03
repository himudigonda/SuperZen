import SwiftUI

nonisolated enum ZenSliderMath {
  static func value(fraction: Double, in range: ClosedRange<Double>, step: Double?) -> Double {
    let clamped = min(1, max(0, fraction.isFinite ? fraction : 0))
    let raw = range.lowerBound + (range.upperBound - range.lowerBound) * clamped
    guard let step, step > 0 else { return raw }
    let snapped = range.lowerBound + ((raw - range.lowerBound) / step).rounded() * step
    return min(range.upperBound, max(range.lowerBound, snapped))
  }

  static func fraction(value: Double, in range: ClosedRange<Double>) -> Double {
    let span = range.upperBound - range.lowerBound
    guard span > 0, value.isFinite else { return 0 }
    return min(1, max(0, (value - range.lowerBound) / span))
  }
}

struct ZenSlider: View {
  private let label: String
  @Binding private var value: Double
  private let range: ClosedRange<Double>
  private let step: Double?
  private let valueText: String?
  @Environment(\.isEnabled) private var isEnabled
  @State private var isDragging = false

  private static let trackHeight: CGFloat = 16
  private static let handleHeight: CGFloat = 32
  private static let handleWidth: CGFloat = 4
  private static let gap: CGFloat = 6

  init(
    _ label: String,
    value: Binding<Double>,
    in range: ClosedRange<Double>,
    step: Double? = nil,
    valueText: String? = nil
  ) {
    self.label = label
    self._value = value
    self.range = range
    self.step = step
    self.valueText = valueText
  }

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let fraction = ZenSliderMath.fraction(value: value, in: range)
      let handleX = (width - Self.handleWidth) * fraction
      ZStack(alignment: .leading) {
        Capsule(style: .circular)
          .fill(activeTrack)
          .frame(width: max(0, handleX - Self.gap), height: Self.trackHeight)
        Capsule(style: .circular)
          .fill(inactiveTrack)
          .frame(width: max(0, width - handleX - Self.handleWidth - Self.gap), height: Self.trackHeight)
          .offset(x: handleX + Self.handleWidth + Self.gap)
        Capsule(style: .circular)
          .fill(activeTrack)
          .frame(width: isDragging ? Self.handleWidth - 2 : Self.handleWidth, height: Self.handleHeight)
          .offset(x: handleX)
      }
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            isDragging = true
            value = ZenSliderMath.value(fraction: gesture.location.x / max(1, width), in: range, step: step)
          }
          .onEnded { _ in isDragging = false }
      )
    }
    .frame(height: Self.handleHeight)
    .opacity(isEnabled ? 1 : ZenStateLayer.disabledContent)
    .focusable()
    .focusEffectDisabled()
    .onKeyPress(.leftArrow) {
      nudge(by: -1)
      return .handled
    }
    .onKeyPress(.rightArrow) {
      nudge(by: 1)
      return .handled
    }
    .accessibilityElement()
    .accessibilityLabel(label)
    .accessibilityValue(valueText ?? value.formatted())
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: nudge(by: 1)
      case .decrement: nudge(by: -1)
      @unknown default: break
      }
    }
  }

  private var activeTrack: AnyShapeStyle {
    isEnabled ? AnyShapeStyle(ZenColor.primary) : AnyShapeStyle(ZenColor.onSurface)
  }

  private var inactiveTrack: AnyShapeStyle {
    isEnabled
      ? AnyShapeStyle(ZenColor.secondaryContainer)
      : AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContainer))
  }

  private func nudge(by direction: Double) {
    let increment = step ?? (range.upperBound - range.lowerBound) / 20
    value = min(range.upperBound, max(range.lowerBound, value + direction * increment))
  }
}
