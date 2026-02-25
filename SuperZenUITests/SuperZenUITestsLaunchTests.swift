import XCTest

final class SuperZenUITestsLaunchTests: XCTestCase {
  override static var runsForEachTargetApplicationUIConfiguration: Bool { true }

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testLaunch() throws {
    // SuperZen is a menu-bar-only app; standard UI launch is not applicable.
    throw XCTSkip("SuperZen runs as a menu-bar-only app — no launchable window for UI tests.")
  }
}
