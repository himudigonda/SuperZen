import Carbon.HIToolbox
import Foundation
import OSLog
import SuperZenCore

private let hotkeySignature: OSType = 0x535A_454E

@MainActor
final class CarbonHotkeyRegistrar: HotkeyRegistering {
  var onPress: ((HotkeyAction) -> Void)?

  private var references: [EventHotKeyRef] = []
  private var handler: EventHandlerRef?
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SuperZen", category: "hotkeys")

  func register(_ hotkey: Hotkey, for action: HotkeyAction) -> Bool {
    guard installHandlerIfNeeded() else { return false }
    var reference: EventHotKeyRef?
    let status = RegisterEventHotKey(
      hotkey.keyCode, hotkey.modifiers.carbonFlags,
      EventHotKeyID(signature: hotkeySignature, id: action.hotkeyID),
      GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
    guard status == noErr, let reference else {
      logger.notice("Hotkey \(hotkey.description, privacy: .public) unavailable: \(status)")
      return false
    }
    references.append(reference)
    return true
  }

  func unregisterAll() {
    for reference in references {
      _ = UnregisterEventHotKey(reference)
    }
    references.removeAll()
  }

  func systemReservedHotkeys() -> Set<Hotkey> {
    var unmanaged: Unmanaged<CFArray>?
    guard CopySymbolicHotKeys(&unmanaged) == noErr,
      let entries = unmanaged?.takeRetainedValue() as? [[String: Any]]
    else { return [] }
    return Set(entries.compactMap(Self.hotkey(fromSymbolic:)))
  }

  private static func hotkey(fromSymbolic entry: [String: Any]) -> Hotkey? {
    guard (entry["kHISymbolicHotKeyEnabled"] as? Bool) == true,
      let code = entry["kHISymbolicHotKeyCode"] as? Int,
      let modifiers = entry["kHISymbolicHotKeyModifiers"] as? Int
    else { return nil }
    return Hotkey(
      keyCode: UInt32(truncatingIfNeeded: code),
      modifiers: HotkeyModifiers(carbonFlags: UInt32(truncatingIfNeeded: modifiers)))
  }

  private func installHandlerIfNeeded() -> Bool {
    guard handler == nil else { return true }
    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let context = Unmanaged.passRetained(self).toOpaque()
    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, context in
        guard let event, let context else { return OSStatus(eventNotHandledErr) }
        var identifier = EventHotKeyID()
        let status = GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
          MemoryLayout<EventHotKeyID>.size, nil, &identifier)
        guard status == noErr, identifier.signature == hotkeySignature,
          let action = HotkeyAction(hotkeyID: identifier.id)
        else { return OSStatus(eventNotHandledErr) }
        let registrar = Unmanaged<CarbonHotkeyRegistrar>.fromOpaque(context).takeUnretainedValue()
        MainActor.assumeIsolated { registrar.onPress?(action) }
        return noErr
      }, 1, &spec, context, &handler)
    guard status == noErr else {
      Unmanaged<CarbonHotkeyRegistrar>.fromOpaque(context).release()
      logger.error("Could not install hotkey handler: \(status)")
      return false
    }
    return true
  }
}
