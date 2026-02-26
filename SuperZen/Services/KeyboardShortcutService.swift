import AppKit
import ApplicationServices

class KeyboardShortcutService {
  static let shared = KeyboardShortcutService()

  private var globalMonitor: Any?
  private var localMonitor: Any?

  struct Shortcut {
    let id: String
    let flags: NSEvent.ModifierFlags
    let key: String
    let action: () -> Void
  }

  private var shortcuts: [Shortcut] = []

  @MainActor
  func setupShortcuts(stateManager: StateManager) {
    unregisterAll()

    // 1. Prompt for Accessibility Permissions
    // macOS requires this to listen to global keyboard events outside the app
    requestAccessibility()

    let defaults = UserDefaults.standard

    // 2. Parse and Register
    register(id: "startBreak", combo: defaults.string(forKey: "shortcutStartBreak") ?? "⌃⌥⌘B") {
      stateManager.transition(to: .onBreak)
    }

    register(id: "togglePause", combo: defaults.string(forKey: "shortcutTogglePause") ?? "⌃⌥⌘P") {
      stateManager.togglePause()
    }

    register(id: "skipBreak", combo: defaults.string(forKey: "shortcutSkipBreak") ?? "⌃⌥⌘S") {
      if stateManager.status == .onBreak && stateManager.canSkip {
        stateManager.transition(to: .active)
      }
    }

    // 3. Start the actual event listeners
    startMonitoring()
  }

  private func requestAccessibility() {
    let options =
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  private func register(id: String, combo: String, action: @escaping () -> Void) {
    var flags: NSEvent.ModifierFlags = []
    var key = ""

    // Simple parser for our combo strings (e.g., "⌃⌥⌘B")
    for char in combo {
      if char == "⌃" {
        flags.insert(.control)
      } else if char == "⌥" {
        flags.insert(.option)
      } else if char == "⌘" {
        flags.insert(.command)
      } else if char == "⇧" {
        flags.insert(.shift)
      } else {
        key = String(char).lowercased()
      }
    }

    shortcuts.append(Shortcut(id: id, flags: flags, key: key, action: action))
    print("SuperZen: Registered Global Shortcut [\(id)]: \(combo)")
  }

  private func startMonitoring() {
    let handler: (NSEvent) -> Void = { [weak self] event in
      guard let self = self else { return }

      // Clean up the flags to ignore Caps Lock, Num Pad, etc.
      let eventFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
      guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return }

      for shortcut in self.shortcuts {
        if shortcut.flags == eventFlags && shortcut.key == chars {
          DispatchQueue.main.async { shortcut.action() }
        }
      }
    }

    // Listens when the app is in the background
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)

    // Listens when the app is in the foreground
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      handler(event)
      return event
    }
  }

  func unregisterAll() {
    shortcuts.removeAll()
    if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
    if let lm = localMonitor { NSEvent.removeMonitor(lm) }
    globalMonitor = nil
    localMonitor = nil
  }
}
