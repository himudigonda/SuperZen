import Foundation

public struct HotkeyModifiers: OptionSet, Hashable, Sendable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let control = HotkeyModifiers(rawValue: 1 << 0)
  public static let option = HotkeyModifiers(rawValue: 1 << 1)
  public static let shift = HotkeyModifiers(rawValue: 1 << 2)
  public static let command = HotkeyModifiers(rawValue: 1 << 3)

  static let ordered: [(HotkeyModifiers, Character, UInt32)] = [
    (.control, "⌃", 1 << 12),
    (.option, "⌥", 1 << 11),
    (.shift, "⇧", 1 << 9),
    (.command, "⌘", 1 << 8),
  ]

  public var carbonFlags: UInt32 {
    Self.ordered.reduce(0) { contains($1.0) ? $0 | $1.2 : $0 }
  }

  public init(carbonFlags: UInt32) {
    self = Self.ordered.reduce(into: []) { result, entry in
      if carbonFlags & entry.2 != 0 { result.insert(entry.0) }
    }
  }

  public var symbols: String {
    String(Self.ordered.compactMap { contains($0.0) ? $0.1 : nil })
  }

  public var hasNonShiftModifier: Bool {
    !intersection([.control, .option, .command]).isEmpty
  }
}

public struct Hotkey: Hashable, Sendable, CustomStringConvertible {
  public let keyCode: UInt32
  public let modifiers: HotkeyModifiers

  public init(keyCode: UInt32, modifiers: HotkeyModifiers) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  public init?(_ combo: String) {
    var modifiers: HotkeyModifiers = []
    var rest = Substring(combo.trimmingCharacters(in: .whitespaces))
    while let first = rest.first,
      let entry = HotkeyModifiers.ordered.first(where: { $0.1 == first })
    {
      modifiers.insert(entry.0)
      rest = rest.dropFirst()
    }
    guard let keyCode = KeyCodes.code(for: String(rest)) else { return nil }
    self.init(keyCode: keyCode, modifiers: modifiers)
  }

  public var description: String {
    modifiers.symbols + (KeyCodes.label(for: keyCode) ?? "?")
  }
}

public enum KeyCodes {
  private static let table: [(UInt32, String)] = [
    (0, "A"), (11, "B"), (8, "C"), (2, "D"), (14, "E"), (3, "F"), (5, "G"), (4, "H"),
    (34, "I"), (38, "J"), (40, "K"), (37, "L"), (46, "M"), (45, "N"), (31, "O"), (35, "P"),
    (12, "Q"), (15, "R"), (1, "S"), (17, "T"), (32, "U"), (9, "V"), (13, "W"), (7, "X"),
    (16, "Y"), (6, "Z"),
    (29, "0"), (18, "1"), (19, "2"), (20, "3"), (21, "4"), (23, "5"), (22, "6"), (26, "7"),
    (28, "8"), (25, "9"),
    (27, "-"), (24, "="), (33, "["), (30, "]"), (42, "\\"), (41, ";"), (39, "'"), (43, ","),
    (47, "."), (44, "/"), (50, "`"),
    (49, "Space"), (48, "Tab"), (36, "Return"), (51, "Delete"), (53, "Esc"),
    (123, "←"), (124, "→"), (125, "↓"), (126, "↑"),
    (122, "F1"), (120, "F2"), (99, "F3"), (118, "F4"), (96, "F5"), (97, "F6"), (98, "F7"),
    (100, "F8"), (101, "F9"), (109, "F10"), (103, "F11"), (111, "F12"),
  ]

  private static let byLabel: [String: UInt32] = Dictionary(
    uniqueKeysWithValues: table.map { ($0.1.uppercased(), $0.0) })
  private static let byCode: [UInt32: String] = Dictionary(
    uniqueKeysWithValues: table.map { ($0.0, $0.1) })

  public static let escape: UInt32 = 53

  public static func code(for label: String) -> UInt32? {
    byLabel[label.uppercased()]
  }

  public static func label(for code: UInt32) -> String? {
    byCode[code]
  }
}
