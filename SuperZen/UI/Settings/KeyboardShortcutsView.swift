import AppKit
import SuperZenCore
import SwiftUI

struct KeyboardShortcutsView: View {
  @ObservedObject var hotkeys: HotkeyCenter
  @State private var drafts: [HotkeyAction: String] = [:]

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Global Shortcuts")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)

        let plan = hotkeys.preview(drafts)
        ZenCard {
          ForEach(Array(HotkeyAction.allCases.enumerated()), id: \.element) { index, action in
            if index > 0 { ZenRowDivider() }
            ShortcutRow(
              title: action.title, shortcut: binding(for: action), issue: issue(for: action, in: plan))
          }
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("Tips")
          .font(.headline)
          .foregroundColor(Theme.textPrimary)
        Text(
          String(
            localized:
              "Shortcuts work even when SuperZen is in the background. Use them to take control without opening the dashboard.",
            comment: "Keyboard shortcuts tip text")
        )
        .font(.system(size: 11))
        .foregroundColor(Theme.textSecondary)
        .lineSpacing(4)
      }

      Spacer()

      SettingsSaveBar(onSave: save)
    }
    .task { load() }
  }

  private func binding(for action: HotkeyAction) -> Binding<String> {
    Binding(
      get: { drafts[action] ?? action.defaultCombo },
      set: { drafts[action] = $0 })
  }

  private func issue(for action: HotkeyAction, in plan: [HotkeyAction: HotkeyStatus]) -> HotkeyIssue? {
    if let issue = plan[action]?.issue { return issue }
    let saved = HotkeyCenter.combos(in: .standard)[action]
    return drafts[action] == saved ? hotkeys.statuses[action]?.issue : nil
  }

  private func load() {
    drafts = HotkeyCenter.combos(in: .standard)
  }

  private func save() {
    for (action, combo) in drafts {
      UserDefaults.standard.set(combo, forKey: action.settingKey)
    }
  }
}

struct ShortcutRow: View {
  let title: String
  @Binding var shortcut: String
  var issue: HotkeyIssue?
  @State private var isRecording = false
  @State private var monitor: Any?

  var body: some View {
    ZenRow(title: title, subtitle: issue.map { "⚠︎ " + $0.message }) {
      let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
      Button(action: { startRecording() }) {
        Text(
          isRecording
            ? String(localized: "Press keys...", comment: "Keyboard shortcut recorder placeholder")
            : shortcut
        )
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
