import SwiftUI

struct KeyboardShortcutsView: View {
  @AppStorage("shortcutStartBreak") var shortcutStartBreak = "⌃⌥⌘B"
  @AppStorage("shortcutTogglePause") var shortcutTogglePause = "⌃⌥⌘P"
  @AppStorage("shortcutSkipBreak") var shortcutSkipBreak = "⌃⌥⌘S"

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Global Shortcuts")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        ZenCard {
          ShortcutRow(title: "Start break now", shortcut: $shortcutStartBreak)
          ZenRowDivider()
          ShortcutRow(title: "Toggle pause", shortcut: $shortcutTogglePause)
          ZenRowDivider()
          ShortcutRow(title: "Skip current break", shortcut: $shortcutSkipBreak)
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("Tips")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)
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
      let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
      Button(action: { startRecording() }) {
        Text(isRecording ? "Press keys..." : shortcut)
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background {
            if isRecording {
              shape.fill(Theme.accentGradient)
            } else {
              shape.fill(.thinMaterial)
              shape.fill(
                LinearGradient(
                  colors: [
                    Theme.surfaceTintTop.opacity(0.88), Theme.surfaceTintBottom.opacity(0.74),
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
            }
          }
          .foregroundColor(isRecording ? .white : Theme.textPrimary)
          .overlay(
            shape.stroke(isRecording ? Theme.accent.opacity(0.4) : Theme.pillStroke, lineWidth: 1)
          )
          .shadow(color: Theme.cardShadow.opacity(isRecording ? 0.45 : 0.2), radius: 8, x: 0, y: 3)
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
