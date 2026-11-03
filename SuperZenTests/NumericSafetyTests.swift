import Foundation
import Testing

@testable import SuperZen

@MainActor
struct NumericSafetyTests {
  nonisolated static let hostileValues: [Double] = [
    .nan, .infinity, -.infinity, 1e300, -1e300, .greatestFiniteMagnitude, -.greatestFiniteMagnitude,
  ]

  @Test(arguments: hostileValues)
  func spokenTimeNeverTraps(_ seconds: Double) {
    #expect(!SpokenTimeFormatter.spokenTime(seconds).isEmpty)
  }

  @Test(arguments: hostileValues)
  func durationNeverTraps(_ seconds: Double) {
    #expect(!InsightsFormat.duration(seconds).isEmpty)
  }

  @Test(arguments: hostileValues)
  func trendNeverTraps(_ fraction: Double) {
    #expect(!InsightsFormat.trend(fraction).isEmpty)
  }

  @Test(arguments: hostileValues)
  func percentNeverTraps(_ fraction: Double) {
    _ = InsightsViewModel.percent(fraction)
  }

  @Test func saturatingConversionClampsInsteadOfTrapping() {
    #expect(Int(saturating: .nan) == 0)
    #expect(Int(saturating: .infinity) == Int.max)
    #expect(Int(saturating: -.infinity) == Int.min)
    #expect(Int(saturating: 1e300) == Int.max)
    #expect(Int(saturating: Double(Int.max)) == Int.max)
    #expect(Int(saturating: -1e300) == Int.min)
    #expect(Int(saturating: 41.9) == 41)
    #expect(Int(saturating: -41.9) == -41)
  }

  @Test func ordinaryValuesAreUnchanged() {
    #expect(SpokenTimeFormatter.spokenTime(0) == SpokenTimeFormatter.spokenTime(-5))
    #expect(InsightsFormat.duration(5400) == "1h 30m")
    #expect(InsightsFormat.duration(120) == "2m")
    #expect(InsightsFormat.duration(-30) == "0m")
    #expect(InsightsFormat.trend(0.25) == "+25%")
    #expect(InsightsFormat.trend(-0.5) == "-50%")
    #expect(InsightsViewModel.percent(0.456) == 46)
    #expect(InsightsViewModel.percent(nil) == 0)
  }
}
