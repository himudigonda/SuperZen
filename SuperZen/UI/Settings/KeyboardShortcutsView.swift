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

  var body: some View {
    ZenRow(title: title) {
      Button(action: { isRecording.toggle() }) {
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
    // Logic to capture keys would be added here via a background NSEvent monitor
  }
}
