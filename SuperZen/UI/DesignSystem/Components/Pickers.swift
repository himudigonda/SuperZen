import SwiftUI

struct PickerPill: View {
  let text: String
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    HStack(spacing: ZenSpacing.xs) {
      Text(text)
        .font(ZenFont.labelLarge)
        .lineLimit(1)
      Image(systemName: "chevron.down")
        .font(ZenFont.iconSmall)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, ZenSpacing.sm)
    .frame(minHeight: 32)
    .foregroundStyle(ZenColor.onSecondaryContainer)
    .background(ZenColor.secondaryContainer, in: Capsule(style: .circular))
    .overlay(
      Capsule(style: .circular).fill(ZenColor.onSecondaryContainer)
        .opacity(isHovered && isEnabled ? ZenStateLayer.hover : 0)
        .allowsHitTesting(false)
    )
    .opacity(isEnabled ? 1 : ZenStateLayer.disabledContent)
    .zenFocusRing(Capsule(style: .circular))
    .contentShape(Capsule(style: .circular))
    .fixedSize()
    .onHover { isHovered = $0 }
    .zenAnimation(.quick, value: isHovered)
  }
}

struct MenuPicker<Value: Hashable>: View {
  private let title: String
  @Binding private var selection: Value
  private let options: [Value]
  private let label: (Value) -> String

  init(
    _ title: String,
    selection: Binding<Value>,
    options: [Value],
    label: @escaping (Value) -> String
  ) {
    self.title = title
    self._selection = selection
    self.options = options
    self.label = label
  }

  var body: some View {
    ZenMenu(items: items) {
      PickerPill(text: label(selection))
    }
    .accessibilityLabel(title)
    .accessibilityValue(label(selection))
  }

  private var items: [ZenMenuItem] {
    options.enumerated().map { index, option in
      .action(id: "\(index)", label(option), isSelected: option == selection) {
        selection = option
      }
    }
  }
}

nonisolated enum OptionLabel {
  static func localized(_ raw: String, bundle: Bundle = .main) -> String {
    bundle.localizedString(forKey: raw, value: raw, table: nil)
  }
}

extension MenuPicker {
  init(_ title: String, selection: Binding<Value>, catalog: [(String, Value)]) {
    self.init(title, selection: selection, options: catalog.map { $0.1 }) { value in
      catalog.first { $0.1 == value }.map { OptionLabel.localized($0.0) } ?? String(describing: value)
    }
  }
}

struct PillButton: View {
  private let title: String
  private let role: ButtonRole?
  private let action: () -> Void

  init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
    self.title = title
    self.role = role
    self.action = action
  }

  var body: some View {
    Button(role: role, action: action) {
      Text(title)
    }
    .buttonStyle(ZenButtonStyle(kind: role == .destructive ? .destructive : .tonal, size: .small))
  }
}

nonisolated enum DurationFormat {
  static func compact(_ totalSeconds: Double) -> String {
    let total = max(0, Int(exactly: totalSeconds.rounded()) ?? 0)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    var parts: [String] = []
    if hours > 0 { parts.append("\(hours)h") }
    if minutes > 0 { parts.append("\(minutes)m") }
    if seconds > 0 || parts.isEmpty { parts.append("\(seconds)s") }
    return parts.joined(separator: " ")
  }

  static func seconds(hours: String, minutes: String, seconds: String) -> Int {
    func parse(_ text: String) -> Double {
      let number = text.filter { $0.isNumber || $0 == "." || $0 == "," }.replacingOccurrences(of: ",", with: ".")
      let parts = number.split(separator: ".", omittingEmptySubsequences: false)
      let whole = Double(parts.first?.prefix(6) ?? "") ?? 0
      guard parts.count == 2, let fraction = Double("0." + parts[1].prefix(6)) else { return whole }
      return whole + fraction
    }
    return Int((parse(hours) * 3600 + parse(minutes) * 60 + parse(seconds)).rounded())
  }
}

struct DurationPicker: View {
  private let title: String
  @Binding private var value: Double
  private let options: [(String, Double)]
  private let minimum: Int

  @State private var showingCustom = false
  @State private var customHours = ""
  @State private var customMinutes = ""
  @State private var customSeconds = ""
  @State private var customError: String?

  init(_ title: String, value: Binding<Double>, options: [(String, Double)], minimum: Int = 1) {
    self.title = title
    self._value = value
    self.options = options
    self.minimum = minimum
  }

  var body: some View {
    ZenMenu(items: items) {
      PickerPill(text: DurationFormat.compact(value))
    }
    .accessibilityLabel(title)
    .accessibilityValue(DurationFormat.compact(value))
    .zenDialog(isPresented: $showingCustom, dismissesOnScrimTap: false) { customEditor }
  }

  private var items: [ZenMenuItem] {
    var rows: [ZenMenuItem] = options.map { option in
      .action(id: "\(option.1)", OptionLabel.localized(option.0), isSelected: option.1 == value) {
        value = option.1
      }
    }
    rows.append(.divider(id: "custom-divider"))
    rows.append(
      .action(
        id: "custom", String(localized: "Custom...", comment: "Duration picker: open custom duration editor"),
        action: { openCustomEditor() }))
    return rows
  }

  private var customEditor: some View {
    ZenDialogSurface(
      title: String(localized: "Custom Duration"),
      message: String(localized: "Set \(title) in hours, minutes, and seconds."),
      width: 440
    ) {
      VStack(alignment: .leading, spacing: ZenSpacing.xs) {
        HStack(spacing: ZenSpacing.sm) {
          durationField(String(localized: "Hours", comment: "Custom duration field"), $customHours)
          durationField(String(localized: "Minutes", comment: "Custom duration field"), $customMinutes)
          durationField(String(localized: "Seconds", comment: "Custom duration field"), $customSeconds)
        }
        if let customError {
          Text(customError)
            .font(ZenFont.bodySmall)
            .foregroundStyle(ZenColor.error)
        }
      }
    } actions: {
      Button("Cancel", role: .cancel) {
        showingCustom = false
        customError = nil
      }
      .buttonStyle(.zenText)
      Button("Apply") { applyCustomDuration() }
        .buttonStyle(.zenFilled)
        .keyboardShortcut(.defaultAction)
    }
  }

  private func durationField(_ label: String, _ text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
      Text(label)
        .font(ZenFont.labelMedium)
        .foregroundStyle(ZenColor.onSurfaceVariant)
      ZenTextField(label, text: text, prompt: "0", isError: customError != nil)
    }
    .frame(maxWidth: .infinity)
  }

  private func openCustomEditor() {
    let total = max(minimum, Int(exactly: value.rounded()) ?? minimum)
    customHours = String(total / 3600)
    customMinutes = String((total % 3600) / 60)
    customSeconds = String(total % 60)
    customError = nil
    showingCustom = true
  }

  private func applyCustomDuration() {
    let total = DurationFormat.seconds(
      hours: customHours, minutes: customMinutes, seconds: customSeconds)
    guard total >= minimum else {
      customError = String(
        localized: "Duration must be at least \(DurationFormat.compact(Double(minimum))).",
        comment: "Custom duration validation error with the minimum length")
      return
    }
    value = Double(total)
    customError = nil
    showingCustom = false
  }
}
