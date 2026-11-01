import SwiftUI

struct KeyboardShortcutsView: View {
  @State private var shortcutStartBreak: String = SettingsCatalog.shortcutStartBreakDefault
  @State private var shortcutTogglePause: String = SettingsCatalog.shortcutTogglePauseDefault
  @State private var shortcutSkipBreak: String = SettingsCatalog.shortcutSkipBreakDefault

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxl) {
      CardSection("Global Shortcuts") {
        ShortcutRow(
          title: String(localized: "Start break now", comment: "Keyboard shortcut row title"),
          shortcut: $shortcutStartBreak)
        CardDivider()
        ShortcutRow(
          title: String(localized: "Toggle pause", comment: "Keyboard shortcut row title"),
          shortcut: $shortcutTogglePause)
        CardDivider()
        ShortcutRow(
          title: String(localized: "Skip current break", comment: "Keyboard shortcut row title"),
          shortcut: $shortcutSkipBreak)
      }

      VStack(alignment: .leading, spacing: ZenSpacing.xs) {
        SectionHeader("Tips")
        Text(
          String(
            localized:
              "Shortcuts work even when SuperZen is in the background. Use them to take control without opening the dashboard.",
            comment: "Keyboard shortcuts tip text")
        )
        .font(ZenFont.subheadline)
        .foregroundStyle(ZenColor.textSecondary)
        .lineSpacing(ZenSpacing.xxs)
      }

      Spacer()

      SettingsSaveBar(onSave: save)
    }
    .task { load() }
  }

  private func load() {
    let d = UserDefaults.standard
    shortcutStartBreak =
      d.string(forKey: SettingKey.shortcutStartBreak) ?? SettingsCatalog.shortcutStartBreakDefault
    shortcutTogglePause =
      d.string(forKey: SettingKey.shortcutTogglePause) ?? SettingsCatalog.shortcutTogglePauseDefault
    shortcutSkipBreak =
      d.string(forKey: SettingKey.shortcutSkipBreak) ?? SettingsCatalog.shortcutSkipBreakDefault
  }

  private func save() {
    let d = UserDefaults.standard
    d.set(shortcutStartBreak, forKey: SettingKey.shortcutStartBreak)
    d.set(shortcutTogglePause, forKey: SettingKey.shortcutTogglePause)
    d.set(shortcutSkipBreak, forKey: SettingKey.shortcutSkipBreak)
  }
}

struct ShortcutRow: View {
  let title: String
  @Binding var shortcut: String
  @State private var isRecording = false
  @State private var monitor: Any?
  private static let escapeKeyCode: UInt16 = 53

  var body: some View {
    SettingRow(title) {
      let shape = RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous)
      Button(action: { startRecording() }) {
        Text(
          isRecording
            ? String(localized: "Press keys...", comment: "Keyboard shortcut recorder placeholder")
            : shortcut
        )
        .font(ZenFont.keycap)
        .padding(.horizontal, ZenSpacing.sm)
        .padding(.vertical, ZenSpacing.xxs + 2)
        .background {
          if isRecording {
            shape.fill(ZenGradient.accent)
          } else {
            shape.fill(.thinMaterial)
            shape.fill(ZenGradient.surface)
          }
        }
        .foregroundStyle(isRecording ? ZenColor.onAccent : ZenColor.textPrimary)
        .overlay(shape.strokeBorder(ZenColor.controlStroke, lineWidth: 1))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(title)
      .accessibilityValue(isRecording ? String(localized: "Recording", comment: "Shortcut recorder state") : shortcut)
      .accessibilityHint(
        String(localized: "Press to record a new shortcut", comment: "Shortcut recorder hint"))
    }
    .onDisappear { stopRecording() }
  }

  private func startRecording() {
    guard !isRecording else {
      stopRecording()
      return
    }
    isRecording = true
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      handleEvent(event)
      return nil
    }
  }

  private func stopRecording() {
    isRecording = false
    if let localMonitor = monitor {
      NSEvent.removeMonitor(localMonitor)
      monitor = nil
    }
  }

  private func handleEvent(_ event: NSEvent) {
    let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
    guard let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty else {
      return
    }

    if event.keyCode == Self.escapeKeyCode {
      stopRecording()
      return
    }

    var result = ""
    if flags.contains(.control) { result += "⌃" }
    if flags.contains(.option) { result += "⌥" }
    if flags.contains(.shift) { result += "⇧" }
    if flags.contains(.command) { result += "⌘" }

    guard !result.isEmpty else { return }

    shortcut = result + chars
    stopRecording()
  }
}
