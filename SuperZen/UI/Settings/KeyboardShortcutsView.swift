import SwiftUI

struct KeyboardShortcutsView: View {
  @AppStorage("shortcutStartBreak") var shortcutStartBreak = "⌃⌥⌘B"
  @AppStorage("shortcutTogglePause") var shortcutTogglePause = "⌃⌥⌘P"
  @AppStorage("shortcutSkipBreak") var shortcutSkipBreak = "⌃⌥⌘S"

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Global Shortcuts")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)
          .padding(.leading, 4)

        ZenCard {
          ShortcutRow(title: "Start break now", shortcut: $shortcutStartBreak)
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          ShortcutRow(title: "Toggle pause", shortcut: $shortcutTogglePause)
          Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
          ShortcutRow(title: "Skip current break", shortcut: $shortcutSkipBreak)
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("Tips")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(Theme.textPrimary)
          .padding(.leading, 4)
        Text(
          "Shortcuts work even when SuperZen is in the background. "
            + "Use them to take control without opening the dashboard."
        )
        .font(.system(size: 11))
        .foregroundColor(Theme.textSecondary)
        .lineSpacing(4)
      }

      Spacer()
    }
  }
}

struct ShortcutRow: View {
  let title: String
  @Binding var shortcut: String
  @State private var isRecording = false
  @State private var monitor: Any?

  var body: some View {
    ZenRow(title: title) {
      Button(action: { startRecording() }) {
        Text(isRecording ? "Recording..." : shortcut)
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(isRecording ? Color.blue : Color.white.opacity(0.1))
          .cornerRadius(6)
          .foregroundColor(.white)
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
      }
      .buttonStyle(.plain)
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
    if let m = monitor {
      NSEvent.removeMonitor(m)
      monitor = nil
    }
  }

  private func handleEvent(_ event: NSEvent) {
    let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
    guard let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty else {
      return
    }

    if event.keyCode == 53 {  // Escape key cancels
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
