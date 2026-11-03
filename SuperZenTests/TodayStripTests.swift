import Foundation
import SuperZenCore
import SwiftData
import Testing

@testable import SuperZen

@MainActor
struct TodayStripTests {
  private func makeModel(container: ModelContainer, center: NotificationCenter) -> TodayStripModel {
    let defaults = UserDefaults(suiteName: "com.himudigonda.SuperZenTests.strip.\(UUID().uuidString)")!
    return TodayStripModel(
      context: { container.mainContext }, defaults: defaults, notificationCenter: center,
      liveActivity: { nil })
  }

  private func settle() async {
    try? await Task.sleep(for: .milliseconds(150))
  }

  @Test func emptyDayLoadsCalmZeroSummary() async throws {
    let model = makeModel(container: try TelemetryStore.makeInMemoryContainer(), center: NotificationCenter())
    model.activate()
    await settle()
    let summary = try #require(model.summary)
    #expect(!summary.hasActivity)
    #expect(summary.focus == 0)
    #expect(summary.breaksTotal == 0)
  }

  @Test func stopsObservingWhenDeactivated() async throws {
    let center = NotificationCenter()
    let model = makeModel(container: try TelemetryStore.makeInMemoryContainer(), center: center)
    model.activate()
    #expect(model.isObserving)
    model.deactivate()
    #expect(!model.isObserving)
  }

  @Test func releasesAfterUse() async throws {
    let container = try TelemetryStore.makeInMemoryContainer()
    weak var released: TodayStripModel?
    do {
      let model = makeModel(container: container, center: NotificationCenter())
      released = model
      model.activate()
      await settle()
    }
    await settle()
    #expect(released == nil)
  }
}
