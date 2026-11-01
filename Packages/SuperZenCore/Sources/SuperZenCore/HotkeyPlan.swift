public enum HotkeyAction: String, CaseIterable, Hashable, Sendable {
  case startBreak
  case togglePause
  case skipBreak

  public var hotkeyID: UInt32 {
    UInt32(Self.allCases.firstIndex(of: self)! + 1)
  }

  public init?(hotkeyID: UInt32) {
    let index = Int(hotkeyID) - 1
    guard Self.allCases.indices.contains(index) else { return nil }
    self = Self.allCases[index]
  }
}

public enum HotkeyIssue: Equatable, Sendable {
  case unrecognized
  case needsModifier
  case duplicate(of: HotkeyAction)
  case reservedBySystem
  case unavailable
}

public enum HotkeyStatus: Equatable, Sendable {
  case ready(Hotkey)
  case blocked(HotkeyIssue)

  public var hotkey: Hotkey? {
    if case .ready(let hotkey) = self { return hotkey }
    return nil
  }

  public var issue: HotkeyIssue? {
    if case .blocked(let issue) = self { return issue }
    return nil
  }
}

public enum HotkeyPlan {
  public static let wellKnownSystemHotkeys: Set<Hotkey> = [
    "⌘Q", "⌘W", "⌘H", "⌘M", "⌘Tab", "⌘Space", "⌃Space", "⌘,", "⌥⌘Esc",
    "⌃⌘Q", "⌃⌘F", "⇧⌘3", "⇧⌘4", "⇧⌘5", "⌘C", "⌘V", "⌘X", "⌘Z", "⌘A", "⌘S",
  ].reduce(into: []) { result, combo in
    if let hotkey = Hotkey(combo) { result.insert(hotkey) }
  }

  public static func resolve(
    _ combos: [HotkeyAction: String], reserved: Set<Hotkey> = []
  ) -> [HotkeyAction: HotkeyStatus] {
    let blocked = reserved.union(wellKnownSystemHotkeys)
    var claimed: [Hotkey: HotkeyAction] = [:]
    var result: [HotkeyAction: HotkeyStatus] = [:]
    for action in HotkeyAction.allCases {
      guard let combo = combos[action] else { continue }
      result[action] = status(of: combo, for: action, blocked: blocked, claimed: &claimed)
    }
    return result
  }

  private static func status(
    of combo: String, for action: HotkeyAction, blocked: Set<Hotkey>,
    claimed: inout [Hotkey: HotkeyAction]
  ) -> HotkeyStatus {
    guard let hotkey = Hotkey(combo) else { return .blocked(.unrecognized) }
    guard hotkey.modifiers.hasNonShiftModifier else { return .blocked(.needsModifier) }
    guard !blocked.contains(hotkey) else { return .blocked(.reservedBySystem) }
    if let owner = claimed[hotkey] { return .blocked(.duplicate(of: owner)) }
    claimed[hotkey] = action
    return .ready(hotkey)
  }
}
