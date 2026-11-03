import Foundation
import Testing

@testable import SuperZenCore

private struct SplitMix64: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }
}

@Suite struct BreakContentTests {
  @Test(arguments: BreakKind.allCases)
  func everyKindHasAtLeastFiveTips(kind: BreakKind) {
    #expect(BreakContent.tips(for: kind).count >= 5)
  }

  @Test func idsAreUniqueStableStringsNamedAfterTheirKind() {
    let ids = BreakTip.allCases.map(\.id)
    #expect(Set(ids).count == ids.count)
    for tip in BreakTip.allCases {
      #expect(tip.id.hasPrefix("tip.\(tip.kind.rawValue)."))
      #expect(tip.id == tip.rawValue)
      #expect(BreakContent.tip(withID: tip.id) == tip)
    }
  }

  @Test func idsAreFrozenBecauseTheyKeyTheStringCatalog() {
    #expect(
      BreakTip.allCases.map(\.id) == [
        "tip.short.look-far", "tip.short.roll-shoulders", "tip.short.close-eyes", "tip.short.blink-slowly",
        "tip.short.unclench-jaw", "tip.short.breathe-slowly", "tip.short.sit-tall", "tip.long.stand-stretch",
        "tip.long.walk", "tip.long.drink-water", "tip.long.window", "tip.long.neck-tilt", "tip.long.wrists",
        "tip.long.fresh-air",
      ])
  }

  @Test func everyTipHasDistinctEnglishText() {
    let texts = BreakTip.allCases.map(\.englishText)
    #expect(Set(texts).count == texts.count)
    for text in texts {
      #expect(!text.isEmpty)
      #expect(text == text.trimmingCharacters(in: .whitespacesAndNewlines))
      #expect(text.hasSuffix("."))
    }
  }

  @Test func englishDefaultsCoverEveryID() {
    let defaults = BreakContent.englishDefaults
    #expect(defaults.count == BreakTip.allCases.count)
    #expect(defaults["tip.short.look-far"] == "Look at something 20 feet away.")
    #expect(BreakContent.englishText(forID: "tip.long.drink-water") == "Drink a glass of water.")
    #expect(BreakContent.englishText(forID: "tip.unknown") == nil)
    #expect(BreakContent.tip(withID: "") == nil)
  }

  @Test(arguments: BreakKind.allCases)
  func neverRepeatsTheLastTipOverAThousandDraws(kind: BreakKind) {
    var generator = SplitMix64(state: 42)
    var last: String?
    var seen = Set<String>()
    for _ in 0..<1000 {
      let tip = BreakContent.next(for: kind, excluding: last, using: &generator)
      #expect(tip.kind == kind)
      #expect(tip.id != last)
      last = tip.id
      seen.insert(tip.id)
    }
    #expect(seen.count == BreakContent.tips(for: kind).count)
  }

  @Test func sameSeedGivesTheSameSequence() {
    func sequence(seed: UInt64) -> [String] {
      var generator = SplitMix64(state: seed)
      var last: String?
      return (0..<50).map { _ in
        let tip = BreakContent.next(for: .short, excluding: last, using: &generator)
        last = tip.id
        return tip.id
      }
    }
    #expect(sequence(seed: 7) == sequence(seed: 7))
    #expect(sequence(seed: 7) != sequence(seed: 8))
  }

  @Test func anExcludedIDFromTheOtherKindExcludesNothing() {
    var generator = SplitMix64(state: 1)
    var picked = Set<String>()
    for _ in 0..<500 {
      picked.insert(BreakContent.next(for: .short, excluding: "tip.long.walk", using: &generator).id)
    }
    #expect(picked.count == BreakContent.tips(for: .short).count)
  }

  @Test func nilAndUnknownLastIDsAreAccepted() {
    var generator = SplitMix64(state: 3)
    #expect(BreakContent.next(for: .long, excluding: nil, using: &generator).kind == .long)
    #expect(BreakContent.next(for: .long, excluding: "garbage", using: &generator).kind == .long)
  }

  @Test func systemRandomOverloadHonoursTheExclusion() {
    var last: String?
    for _ in 0..<200 {
      let tip = BreakContent.next(for: .long, excluding: last)
      #expect(tip.id != last)
      last = tip.id
    }
  }
}
