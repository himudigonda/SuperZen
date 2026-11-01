import SuperZenCore
import Testing

@testable import SuperZen

@MainActor
struct AppStatusTests {
  struct Expectation: Sendable, CustomTestStringConvertible {
    let status: AppStatus
    let description: String
    let isPaused: Bool

    var testDescription: String { description }
  }

  static let table: [Expectation] = [
    Expectation(status: .active, description: "Focusing", isPaused: false),
    Expectation(status: .nudge, description: "Break soon", isPaused: false),
    Expectation(status: .onBreak, description: "On Break", isPaused: false),
    Expectation(status: .wellness(type: .posture), description: "Wellness: Posture", isPaused: false),
    Expectation(status: .wellness(type: .blink), description: "Wellness: Blink", isPaused: false),
    Expectation(status: .wellness(type: .water), description: "Wellness: Water", isPaused: false),
    Expectation(status: .wellness(type: .affirmation), description: "Affirmation", isPaused: false),
    Expectation(status: .paused, description: "Paused", isPaused: true),
  ]

  @Test(arguments: table)
  func describesEachStatus(_ expected: Expectation) {
    #expect(expected.status.description == expected.description)
    #expect(expected.status.isPaused == expected.isPaused)
    #expect(!expected.status.localizedLabel.isEmpty)
  }

  @Test func everyStatusHasADistinctDescription() {
    #expect(Set(Self.table.map(\.status.description)).count == Self.table.count)
  }

  @Test(arguments: WellnessKind.allCases)
  func wellnessStatusesCompareByKind(_ kind: WellnessKind) {
    #expect(AppStatus.wellness(type: kind) == .wellness(type: kind))
    for other in WellnessKind.allCases where other != kind {
      #expect(AppStatus.wellness(type: kind) != .wellness(type: other))
    }
    #expect(!kind.localizedName.isEmpty)
  }
}
