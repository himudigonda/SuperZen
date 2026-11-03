import Foundation

public struct HourSkipStats: Equatable, Sendable {
  public var hour: Int
  public var total: Int
  public var skipped: Int

  public init(hour: Int, total: Int, skipped: Int) {
    self.hour = hour
    self.total = total
    self.skipped = skipped
  }

  public var rate: Double { total > 0 ? Double(skipped) / Double(total) : 0 }
}

public enum SkipAdvice: Equatable, Sendable {
  case insufficientData
  case noPattern
  case plannedBreak(hour: Int, skipRate: Double)
}

public struct SkipPattern: Equatable, Sendable {
  public static let minimumBreaksPerHour = 5
  public static let adviceThreshold = 0.5

  public var hours: [HourSkipStats]
  public var worst: HourSkipStats?
  public var advice: SkipAdvice

  public init(hours: [HourSkipStats], worst: HourSkipStats?, advice: SkipAdvice) {
    self.hours = hours
    self.worst = worst
    self.advice = advice
  }

  public static func analyze(
    _ breaks: [BreakRecord],
    calendar: Calendar = .current,
    minimumPerHour: Int = SkipPattern.minimumBreaksPerHour
  ) -> SkipPattern {
    var totals = [Int: Int]()
    var skips = [Int: Int]()
    for record in breaks {
      let skipped = record.result == .skipped
      guard skipped || record.result == .completed || record.result == .natural else { continue }
      let hour = min(23, max(0, calendar.component(.hour, from: record.start)))
      totals[hour, default: 0] += 1
      if skipped { skips[hour, default: 0] += 1 }
    }
    let required = max(1, minimumPerHour)
    let qualifying = totals.keys.sorted().compactMap { hour -> HourSkipStats? in
      let total = totals[hour] ?? 0
      guard total >= required else { return nil }
      return HourSkipStats(hour: hour, total: total, skipped: skips[hour] ?? 0)
    }
    let worst = qualifying.reduce(nil as HourSkipStats?) { best, candidate in
      guard let best else { return candidate }
      return isWorse(candidate, than: best) ? candidate : best
    }
    return SkipPattern(hours: qualifying, worst: worst, advice: advice(for: worst))
  }

  private static func isWorse(_ candidate: HourSkipStats, than best: HourSkipStats) -> Bool {
    if candidate.rate != best.rate { return candidate.rate > best.rate }
    return candidate.total > best.total
  }

  private static func advice(for worst: HourSkipStats?) -> SkipAdvice {
    guard let worst else { return .insufficientData }
    guard worst.rate >= adviceThreshold else { return .noPattern }
    return .plannedBreak(hour: worst.hour, skipRate: worst.rate)
  }
}
