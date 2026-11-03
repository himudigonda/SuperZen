import AppKit
import SuperZenCore
import SwiftUI

struct KeyboardShortcutsView: View {
  @ObservedObject var hotkeys: HotkeyCenter
  @State private var rejected: [HotkeyAction: RejectedShortcut] = [:]

  var body: some View {
    SettingsPage {
      CardSection("Global Shortcuts") {
        ForEach(Array(HotkeyAction.allCases.enumerated()), id: \.element) { index, action in
          if index > 0 { CardDivider() }
          ShortcutRow(
            title: action.title, shortcut: binding(for: action), issue: issue(for: action))
        }
        CardDivider()
        SettingRow(
          String(localized: "Restore default shortcuts", comment: "Keyboard shortcuts row title")
        ) {
          PillButton(String(localized: "Restore", comment: "Keyboard shortcuts reset button")) {
            rejected.removeAll()
            hotkeys.resetToDefaults()
          }
        }
      }

      PageSection("Tips") {
        Text(
          String(
            localized:
              "Shortcuts work even when SuperZen is in the background, and each one saves as soon as you record it.",
            comment: "Keyboard shortcuts tip text")
        )
        .font(ZenFont.bodySmall)
        .foregroundStyle(ZenColor.onSurfaceVariant)
        .lineSpacing(ZenSpacing.xxs)
        .padding(.horizontal, ZenSpacing.xxs)
      }
    }
  }

  private func binding(for action: HotkeyAction) -> Binding<String> {
    Binding(
      get: { rejected[action]?.combo ?? hotkeys.combos[action] ?? action.defaultCombo },
      set: { combo in
        rejected[action] = hotkeys.assign(combo, to: action).map { RejectedShortcut(combo: combo, issue: $0) }
      })
  }

  private func issue(for action: HotkeyAction) -> HotkeyIssue? {
    rejected[action]?.issue ?? hotkeys.conflicts[action]
  }
}

struct RejectedShortcut: Equatable {
  let combo: String
  let issue: HotkeyIssue
}

struct ShortcutRow: View {
  let title: String
  @Binding var shortcut: String
  var issue: HotkeyIssue?
  @State private var isRecording = false
  @State private var monitor: Any?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SettingRow(title) { recorder }
      if let issue {
        ValidationNote(issue.message)
      }
    }
    .onDisappear { stopRecording() }
  }

  private var recorder: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous)
    return Button(action: { startRecording() }) {
      Text(
        isRecording
          ? String(localized: "Press keys...", comment: "Keyboard shortcut recorder placeholder")
          : shortcut
      )
      .font(ZenFont.keycap)
      .foregroundStyle(isRecording ? ZenColor.onPrimaryContainer : ZenColor.onSurface)
      .padding(.horizontal, ZenSpacing.sm)
      .padding(.vertical, ZenSpacing.xxs + 2)
      .background(
        isRecording ? AnyShapeStyle(ZenColor.primaryContainer) : AnyShapeStyle(ZenColor.surfaceContainerHigh),
        in: shape)
    }
    .buttonStyle(.zenCard)
    .accessibilityLabel(title)
    .accessibilityValue(isRecording ? String(localized: "Recording", comment: "Shortcut recorder state") : shortcut)
    .accessibilityHint(
      String(localized: "Press to record a new shortcut", comment: "Shortcut recorder hint"))
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
    let modifiers = HotkeyModifiers(event.modifierFlags)
    let keyCode = UInt32(event.keyCode)
    if keyCode == KeyCodes.escape && modifiers.isEmpty {
      stopRecording()
      return
    }
    guard !modifiers.isEmpty, KeyCodes.label(for: keyCode) != nil else { return }
    shortcut = Hotkey(keyCode: keyCode, modifiers: modifiers).description
    stopRecording()
  }
}

extension HotkeyModifiers {
  private static let appKitPairs: [(NSEvent.ModifierFlags, HotkeyModifiers)] = [
    (.control, .control), (.option, .option), (.shift, .shift), (.command, .command),
  ]

  init(_ flags: NSEvent.ModifierFlags) {
    self = Self.appKitPairs.reduce(into: []) { result, pair in
      if flags.contains(pair.0) { result.insert(pair.1) }
    }
  }
}
