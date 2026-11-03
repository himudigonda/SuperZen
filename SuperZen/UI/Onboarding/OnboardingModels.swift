import SuperZenCore
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
  case welcome
  case rule
  case rhythm
  case intensity
  case finish

  var id: Int { rawValue }
  var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
  var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
  var isFirst: Bool { previous == nil }
  var isLast: Bool { next == nil }
}

struct TwentyRuleFact: Identifiable, Equatable {
  let value: String
  let unit: String
  let caption: String
  let symbol: String

  var id: String { symbol }

  static func all(work: TimeInterval, rest: TimeInterval) -> [TwentyRuleFact] {
    [
      TwentyRuleFact(
        value: "\(Int(work / 60))",
        unit: String(localized: "minutes", comment: "20-20-20 rule unit"),
        caption: String(localized: "of focused screen time", comment: "20-20-20 rule caption"),
        symbol: "desktopcomputer"),
      TwentyRuleFact(
        value: "20",
        unit: String(localized: "feet", comment: "20-20-20 rule unit"),
        caption: String(localized: "look about 6 metres away", comment: "20-20-20 rule caption"),
        symbol: "binoculars.fill"),
      TwentyRuleFact(
        value: "\(Int(rest))",
        unit: String(localized: "seconds", comment: "20-20-20 rule unit"),
        caption: String(localized: "let your eyes relax", comment: "20-20-20 rule caption"),
        symbol: "eye"),
    ]
  }
}

struct OnboardingCycleSegment: Identifiable, Equatable {
  enum Kind: Equatable {
    case focus
    case eyeBreak
    case longBreak
  }

  let id: Int
  let kind: Kind
  let duration: TimeInterval

  static func cycle(
    work: TimeInterval, rest: TimeInterval, longRest: TimeInterval, longEvery: Int
  ) -> [OnboardingCycleSegment] {
    let blocks = max(1, longEvery)
    return (0..<blocks).flatMap { block -> [OnboardingCycleSegment] in
      let isLastBlock = block == blocks - 1
      return [
        OnboardingCycleSegment(id: block * 2, kind: .focus, duration: work),
        OnboardingCycleSegment(
          id: block * 2 + 1, kind: isLastBlock ? .longBreak : .eyeBreak,
          duration: isLastBlock ? longRest : rest),
      ]
    }
  }
}

enum OnboardingSkipState: Equatable {
  case available
  case locked(seconds: Int)
  case forbidden

  init(difficulty: BreakDifficulty, elapsed: TimeInterval, lock: TimeInterval) {
    switch difficulty {
    case .casual:
      self = .available
    case .hardcore:
      self = .forbidden
    case .balanced:
      let remaining = Int((lock - elapsed).rounded(.up))
      self = remaining > 0 ? .locked(seconds: remaining) : .available
    }
  }

  var canSkip: Bool { self == .available }
}
