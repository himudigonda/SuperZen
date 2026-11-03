import Foundation

public enum BreakTip: String, CaseIterable, Identifiable, Sendable {
  case shortLookFar = "tip.short.look-far"
  case shortRollShoulders = "tip.short.roll-shoulders"
  case shortCloseEyes = "tip.short.close-eyes"
  case shortBlinkSlowly = "tip.short.blink-slowly"
  case shortUnclenchJaw = "tip.short.unclench-jaw"
  case shortBreatheSlowly = "tip.short.breathe-slowly"
  case shortSitTall = "tip.short.sit-tall"
  case longStandStretch = "tip.long.stand-stretch"
  case longWalk = "tip.long.walk"
  case longDrinkWater = "tip.long.drink-water"
  case longWindow = "tip.long.window"
  case longNeckTilt = "tip.long.neck-tilt"
  case longWrists = "tip.long.wrists"
  case longFreshAir = "tip.long.fresh-air"

  public var id: String { rawValue }

  public var kind: BreakKind {
    switch self {
    case .shortLookFar, .shortRollShoulders, .shortCloseEyes, .shortBlinkSlowly, .shortUnclenchJaw,
      .shortBreatheSlowly, .shortSitTall:
      return .short
    case .longStandStretch, .longWalk, .longDrinkWater, .longWindow, .longNeckTilt, .longWrists, .longFreshAir:
      return .long
    }
  }

  public var englishText: String {
    switch self {
    case .shortLookFar: return "Look at something 20 feet away."
    case .shortRollShoulders: return "Roll your shoulders back, slowly."
    case .shortCloseEyes: return "Close your eyes and let them rest."
    case .shortBlinkSlowly: return "Blink slowly a few times."
    case .shortUnclenchJaw: return "Unclench your jaw and relax your hands."
    case .shortBreatheSlowly: return "Take three slow breaths."
    case .shortSitTall: return "Sit tall and let your neck lengthen."
    case .longStandStretch: return "Stand up and stretch your arms overhead."
    case .longWalk: return "Take a short walk."
    case .longDrinkWater: return "Drink a glass of water."
    case .longWindow: return "Look out a window and let your eyes wander."
    case .longNeckTilt: return "Gently tilt your head toward each shoulder."
    case .longWrists: return "Stretch your wrists and fingers."
    case .longFreshAir: return "Step outside for some fresh air if you can."
    }
  }
}

public enum BreakContent {
  public static func tips(for kind: BreakKind) -> [BreakTip] {
    BreakTip.allCases.filter { $0.kind == kind }
  }

  public static func tip(withID id: String) -> BreakTip? {
    BreakTip(rawValue: id)
  }

  public static func englishText(forID id: String) -> String? {
    tip(withID: id)?.englishText
  }

  public static var englishDefaults: [String: String] {
    Dictionary(uniqueKeysWithValues: BreakTip.allCases.map { ($0.id, $0.englishText) })
  }

  public static func next<G: RandomNumberGenerator>(
    for kind: BreakKind,
    excluding last: String?,
    using generator: inout G
  ) -> BreakTip {
    let pool = tips(for: kind)
    let candidates = pool.filter { $0.id != last }
    let choices = candidates.isEmpty ? pool : candidates
    return choices[Int.random(in: 0..<choices.count, using: &generator)]
  }

  public static func next(for kind: BreakKind, excluding last: String?) -> BreakTip {
    var generator = SystemRandomNumberGenerator()
    return next(for: kind, excluding: last, using: &generator)
  }
}
