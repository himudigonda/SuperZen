import XCTest

final class LaunchSmokeTests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testAppLaunchesAndStaysRunning() {
    let app = XCUIApplication()
    app.launchArguments += ["-hasCompletedOnboarding", "YES"]
    app.launch()

    XCTAssertNotEqual(app.state, .notRunning)
    XCTAssertFalse(app.wait(for: .notRunning, timeout: 5), "SuperZen quit or crashed after launch")

    app.terminate()
    XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
  }
}
