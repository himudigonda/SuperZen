import Foundation
import SuperZenCore

struct BreakOverlayCopy: Equatable {
  let difficulty: BreakDifficulty
  let canSkip: Bool
  let skipSecondsRemaining: Int
  var canPostpone = false
  var postponesExhausted = false

  var showsLater: Bool { difficulty != .hardcore }

  var skipTitle: String {
    if difficulty == .hardcore && !canSkip {
      return String(localized: "No skips allowed", comment: "Break screen skip button while hardcore blocks skipping")
    }
    if !canSkip {
      return String(
        localized: "Wait \(skipSecondsRemaining)s",
        comment: "Break screen skip button while the skip lock counts down, with seconds remaining")
    }
    return String(localized: "Skip break", comment: "Break screen skip button")
  }

  var skipAccessibilityLabel: String {
    switch difficulty {
    case .hardcore where !canSkip:
      return String(
        localized: "Skipping disabled in hardcore mode",
        comment: "VoiceOver label for the disabled skip button in hardcore mode")
    case .hardcore, .balanced, .casual:
      return canSkip
        ? String(localized: "Skip break", comment: "VoiceOver label for the enabled skip button")
        : String(
          localized: "Skip available in \(skipSecondsRemaining) seconds",
          comment: "VoiceOver label for the skip button while still locked, with seconds remaining")
    }
  }

  var laterAccessibilityLabel: String {
    if canPostpone {
      return String(localized: "Postpone break", comment: "VoiceOver label for the Later button on the break screen")
    }
    if postponesExhausted {
      return String(
        localized: "No postpones left for this break",
        comment: "VoiceOver label for the disabled Later button once every postpone has been used")
    }
    return String(
      localized: "Postpone available once skipping unlocks",
      comment: "VoiceOver label for the disabled Later button while the skip lock is still active")
  }

  var statusMessage: String {
    if difficulty == .hardcore && canSkip {
      return String(
        localized: "You're on a call. You can skip this break.",
        comment: "Break screen status message in hardcore mode while a call lets the break be skipped")
    }
    if difficulty == .hardcore {
      return String(
        localized: "Stay focused. No skips allowed.",
        comment: "Break screen status message shown in hardcore mode")
    }
    if difficulty == .balanced && !canSkip {
      return String(
        localized: "Almost there. Just wait a few seconds.",
        comment: "Break screen status message while balanced-mode skip lock is active")
    }
    return String(
      localized: "Enjoy a quick break to relax and recharge!",
      comment: "Default break screen status message")
  }
}

extension StateManager {
  var breakOverlayCopy: BreakOverlayCopy {
    BreakOverlayCopy(
      difficulty: difficulty, canSkip: canSkip, skipSecondsRemaining: skipSecondsRemaining,
      canPostpone: menuBar.actions.canPostpone,
      postponesExhausted: session.postponesUsed >= session.settings.timer.maxPostpones)
  }
}
