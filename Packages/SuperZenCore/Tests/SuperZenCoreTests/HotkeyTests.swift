import Testing

@testable import SuperZenCore

@Suite struct HotkeyParsingTests {
  @Test func parsesLegacyDefaultsIntoCarbonValues() throws {
    let hotkey = try #require(Hotkey("⌃⌥⌘B"))
    #expect(hotkey.keyCode == 11)
    #expect(hotkey.modifiers == [.control, .option, .command])
    #expect(hotkey.modifiers.carbonFlags == 4096 | 2048 | 256)
  }

  @Test func modifierOrderDoesNotMatterAndFormatsCanonically() throws {
    let hotkey = try #require(Hotkey("⌘⇧⌥p"))
    #expect(hotkey.description == "⌥⇧⌘P")
    #expect(Hotkey(hotkey.description) == hotkey)
  }

  @Test func namedKeysRoundTrip() throws {
    for combo in ["⌃⌥Space", "⌘F12", "⌥⌘Esc", "⌃⌘←", "⌃⌥,"] {
      let hotkey = try #require(Hotkey(combo))
      #expect(hotkey.description == combo)
    }
  }

  @Test func rejectsUnknownOrEmptyKeys() {
    #expect(Hotkey("⌃⌥⌘") == nil)
    #expect(Hotkey("⌃⌥⌘!") == nil)
    #expect(Hotkey("") == nil)
  }

  @Test func carbonFlagsRoundTrip() {
    let all: HotkeyModifiers = [.control, .option, .shift, .command]
    #expect(HotkeyModifiers(carbonFlags: all.carbonFlags) == all)
    #expect(HotkeyModifiers(carbonFlags: 0) == [])
  }

  @Test func actionIDsRoundTrip() {
    for action in HotkeyAction.allCases {
      #expect(HotkeyAction(hotkeyID: action.hotkeyID) == action)
    }
    #expect(HotkeyAction(hotkeyID: 0) == nil)
    #expect(HotkeyAction(hotkeyID: 99) == nil)
  }
}

@Suite struct HotkeyPlanTests {
  private let defaults: [HotkeyAction: String] = [
    .startBreak: "⌃⌥⌘B", .togglePause: "⌃⌥⌘P", .skipBreak: "⌃⌥⌘S",
  ]

  @Test func defaultsAllResolve() {
    let plan = HotkeyPlan.resolve(defaults)
    #expect(plan[.startBreak] == .ready(Hotkey("⌃⌥⌘B")!))
    #expect(plan.values.allSatisfy { $0.hotkey != nil })
  }

  @Test func duplicateKeepsTheFirstActionAndBlocksTheRest() {
    var combos = defaults
    combos[.skipBreak] = "⌘⌥⌃B"
    let plan = HotkeyPlan.resolve(combos)
    #expect(plan[.startBreak]?.hotkey != nil)
    #expect(plan[.skipBreak] == .blocked(.duplicate(of: .startBreak)))
  }

  @Test func systemReservedCombosAreBlocked() {
    var combos = defaults
    combos[.togglePause] = "⌃⌘Q"
    combos[.skipBreak] = "⌃⌥⌘S"
    let reserved: Set<Hotkey> = [Hotkey("⌃⌥⌘S")!]
    let plan = HotkeyPlan.resolve(combos, reserved: reserved)
    #expect(plan[.togglePause] == .blocked(.reservedBySystem))
    #expect(plan[.skipBreak] == .blocked(.reservedBySystem))
    #expect(plan[.startBreak]?.hotkey != nil)
  }

  @Test func shiftAloneOrNoModifierIsNotEnough() {
    let plan = HotkeyPlan.resolve([.startBreak: "⇧B", .togglePause: "P", .skipBreak: "nonsense"])
    #expect(plan[.startBreak] == .blocked(.needsModifier))
    #expect(plan[.togglePause] == .blocked(.needsModifier))
    #expect(plan[.skipBreak] == .blocked(.unrecognized))
  }

  @Test func blockedComboDoesNotClaimItsKey() {
    let plan = HotkeyPlan.resolve([.startBreak: "⌘Q", .togglePause: "⌥⌘Q"])
    #expect(plan[.startBreak] == .blocked(.reservedBySystem))
    #expect(plan[.togglePause]?.hotkey == Hotkey("⌥⌘Q"))
  }
}
