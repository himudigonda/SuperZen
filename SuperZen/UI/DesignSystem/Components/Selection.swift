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
    HStack(spacing: 0) {
      ForEach(Array(options.enumerated()), id: \.element) { index, option in
        if index > 0 {
          Rectangle().fill(ZenColor.outline).frame(width: 1)
        }
        ZenSegment(
          title: title(option),
          systemImage: systemImage?(option),
          isSelected: option == selection
        ) {
          selection = option
        }
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .clipShape(Capsule(style: .circular))
    .overlay(Capsule(style: .circular).strokeBorder(ZenColor.outline, lineWidth: 1))
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
      .foregroundStyle(isSelected ? ZenColor.onSecondaryContainer : ZenColor.onSurface)
      .padding(.horizontal, ZenSpacing.md)
      .frame(maxWidth: .infinity, minHeight: 40)
      .background(isSelected ? AnyShapeStyle(ZenColor.secondaryContainer) : AnyShapeStyle(Color.clear))
      .overlay(
        Rectangle().fill(ZenColor.onSurface).opacity(isHovered ? ZenStateLayer.hover : 0).allowsHitTesting(false)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .zenAnimation(.quick, value: isHovered)
    .zenAnimation(.quick, value: isSelected)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

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
      .contentShape(shape)
      .opacity(isEnabled ? 1 : ZenStateLayer.disabledContent)
    }
    .buttonStyle(.plain)
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

struct ZenTextField: View {
  private let label: String
  private let prompt: String?
  @Binding private var text: String
  private let isError: Bool
  private let alignment: TextAlignment
  private let width: CGFloat?
  @FocusState private var isFocused: Bool
  @Environment(\.isEnabled) private var isEnabled

  init(
    _ label: String,
    text: Binding<String>,
    prompt: String? = nil,
    isError: Bool = false,
    alignment: TextAlignment = .leading,
    width: CGFloat? = nil
  ) {
    self.label = label
    self._text = text
    self.prompt = prompt
    self.isError = isError
    self.alignment = alignment
    self.width = width
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous)
    TextField(label, text: $text, prompt: prompt.map { Text($0).foregroundStyle(ZenColor.onSurfaceVariant) })
      .textFieldStyle(.plain)
      .labelsHidden()
      .multilineTextAlignment(alignment)
      .font(ZenFont.bodyLarge)
      .foregroundStyle(ZenColor.onSurface)
      .focused($isFocused)
      .focusEffectDisabled()
      .padding(.horizontal, ZenSpacing.sm)
      .frame(width: width)
      .frame(minHeight: 40)
      .overlay {
        shape.strokeBorder(strokeStyle, lineWidth: isFocused ? 2 : 1)
      }
      .opacity(isEnabled ? 1 : ZenStateLayer.disabledContent)
      .zenAnimation(.quick, value: isFocused)
  }

  private var strokeStyle: AnyShapeStyle {
    if isError { return AnyShapeStyle(ZenColor.error) }
    return isFocused ? AnyShapeStyle(ZenColor.primary) : AnyShapeStyle(ZenColor.outline)
  }
}

struct ZenLinearProgress: View {
  let value: Double
  var tint: ZenColor = .primary
  var track: ZenColor = .secondaryContainer
  var height: CGFloat = 4

  var clampedValue: Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  var body: some View {
    GeometryReader { proxy in
      let gap: CGFloat = clampedValue > 0 && clampedValue < 1 ? height : 0
      let active = proxy.size.width * clampedValue
      HStack(spacing: gap) {
        if clampedValue > 0 {
          Capsule(style: .circular).fill(tint).frame(width: max(height, active - gap / 2))
        }
        if clampedValue < 1 {
          Capsule(style: .circular).fill(track)
        }
      }
    }
    .frame(height: height)
    .accessibilityElement()
    .accessibilityValue(Text(clampedValue, format: .percent.precision(.fractionLength(0))))
  }
}

struct ZenCircularProgress: View {
  let value: Double
  var lineWidth: CGFloat = 8
  var tint: ZenColor = .primary
  var track: ZenColor = .secondaryContainer

  private var clampedValue: Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  var body: some View {
    ZStack {
      Circle().stroke(track, lineWidth: lineWidth)
      Circle()
        .trim(from: 0, to: clampedValue)
        .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
    .padding(lineWidth / 2)
  }
}

struct ZenLoadingIndicator: View {
  var size: CGFloat = 24
  var lineWidth: CGFloat = 3
  var tint: ZenColor = .primary
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isRotating = false

  var body: some View {
    Circle()
      .trim(from: 0, to: 0.72)
      .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
      .frame(width: size, height: size)
      .rotationEffect(.degrees(isRotating ? 360 : 0))
      .animation(
        reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: isRotating
      )
      .onAppear { isRotating = true }
      .accessibilityHidden(true)
  }
}

struct ZenDivider: View {
  var body: some View {
    Rectangle()
      .fill(ZenColor.outlineVariant)
      .frame(height: 1)
      .accessibilityHidden(true)
  }
}

struct ZenVerticalDivider: View {
  var height: CGFloat = ZenSpacing.md

  var body: some View {
    Rectangle()
      .fill(ZenColor.outlineVariant)
      .frame(width: 1, height: height)
      .accessibilityHidden(true)
  }
}

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
