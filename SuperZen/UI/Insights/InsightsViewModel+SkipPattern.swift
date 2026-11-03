import Foundation
import SuperZenCore

extension InsightsViewModel {
  func updateSkipAdvice(from snapshot: TelemetrySnapshot, calendar: Calendar = .current) {
    skipAdvice = SkipPattern.analyze(snapshot.breaks, calendar: calendar).advice
  }

  var skipPatternHour: Int? {
    guard case .plannedBreak(let hour, _) = skipAdvice else { return nil }
    return hour
  }
}
