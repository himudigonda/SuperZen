import SwiftUI

struct PickerPill: View {
  let text: String

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous)
    HStack(spacing: ZenSpacing.xs) {
      Text(text)
        .font(ZenFont.calloutEmphasized)
        .lineLimit(1)
      Image(systemName: "chevron.down")
        .font(ZenFont.controlIcon)
        .foregroundStyle(ZenColor.textSecondary)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, ZenSpacing.sm)
    .padding(.vertical, ZenSpacing.xxs + 2)
    .background {
      shape.fill(.thinMaterial)
      shape.fill(ZenGradient.surface)
    }
    .overlay(shape.strokeBorder(ZenColor.controlStroke, lineWidth: 1))
    .glassEffect(.regular, in: shape)
    .foregroundStyle(ZenColor.textPrimary)
  }
}

extension View {
  func zenMenuStyle() -> some View {
    menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
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
    Menu {
      ForEach(options, id: \.self) { option in
        Button {
          selection = option
        } label: {
          if option == selection {
            Label(label(option), systemImage: "checkmark")
          } else {
            Text(label(option))
          }
        }
      }
    } label: {
      PickerPill(text: label(selection))
    }
    .zenMenuStyle()
    .accessibilityLabel(title)
    .accessibilityValue(label(selection))
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
        .font(ZenFont.calloutEmphasized)
        .padding(.horizontal, ZenSpacing.xs)
        .padding(.vertical, ZenSpacing.xxs / 2)
    }
    .buttonStyle(.glassProminent)
    .tint(role == .destructive ? ZenColor.danger : ZenColor.accent)
    .controlSize(.small)
  }
}

nonisolated enum DurationFormat {
  static func compact(_ totalSeconds: Double) -> String {
    let total = max(0, Int(totalSeconds.rounded()))
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
    func parse(_ text: String) -> Int { Int(text.filter(\.isNumber).prefix(6)) ?? 0 }
    return parse(hours) * 3600 + parse(minutes) * 60 + parse(seconds)
  }
}

struct DurationPicker: View {
  private let title: String
  @Binding private var value: Double
  private let options: [(String, Double)]

  @State private var showingCustom = false
  @State private var customHours = ""
  @State private var customMinutes = ""
  @State private var customSeconds = ""
  @State private var customError: String?

  init(_ title: String, value: Binding<Double>, options: [(String, Double)]) {
    self.title = title
    self._value = value
    self.options = options
  }

  var body: some View {
    Menu {
      ForEach(options, id: \.1) { option in
        Button(OptionLabel.localized(option.0)) { value = option.1 }
      }
      Divider()
      Button(
        String(localized: "Custom...", comment: "Duration picker: open custom duration editor"),
        action: { openCustomEditor() })
    } label: {
      PickerPill(text: DurationFormat.compact(value))
    }
    .zenMenuStyle()
    .accessibilityLabel(title)
    .accessibilityValue(DurationFormat.compact(value))
    .sheet(isPresented: $showingCustom) { customEditor }
  }

  private var customEditor: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.md) {
      Text("Custom Duration")
        .font(ZenFont.title)
        .foregroundStyle(ZenColor.textPrimary)

      Text("Set \(title) in hours, minutes, and seconds.")
        .font(ZenFont.body)
        .foregroundStyle(ZenColor.textSecondary)

      HStack(spacing: ZenSpacing.sm) {
        durationField(String(localized: "Hours", comment: "Custom duration field"), $customHours)
        durationField(
          String(localized: "Minutes", comment: "Custom duration field"), $customMinutes)
        durationField(
          String(localized: "Seconds", comment: "Custom duration field"), $customSeconds)
      }

      if let customError {
        Text(customError)
          .font(ZenFont.captionEmphasized)
          .foregroundStyle(ZenColor.danger)
      }

      Spacer()

      HStack {
        Spacer()
        Button("Cancel", role: .cancel) {
          showingCustom = false
          customError = nil
        }
        Button("Apply") { applyCustomDuration() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(ZenSpacing.lg)
    .frame(width: 460, height: 232)
    .background(ZenCanvasBackground())
    .zenThemed()
  }

  private func durationField(_ label: String, _ text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
      Text(label)
        .font(ZenFont.captionEmphasized)
        .foregroundStyle(ZenColor.textSecondary)
      TextField(label, text: text, prompt: Text(verbatim: "0"))
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
    }
    .frame(maxWidth: .infinity)
  }

  private func openCustomEditor() {
    let total = max(1, Int(value.rounded()))
    customHours = String(total / 3600)
    customMinutes = String((total % 3600) / 60)
    customSeconds = String(total % 60)
    customError = nil
    showingCustom = true
  }

  private func applyCustomDuration() {
    let total = DurationFormat.seconds(
      hours: customHours, minutes: customMinutes, seconds: customSeconds)
    guard total >= 1 else {
      customError = String(
        localized: "Duration must be at least 1 second.",
        comment: "Custom duration validation error")
      return
    }
    value = Double(total)
    customError = nil
    showingCustom = false
  }
}
