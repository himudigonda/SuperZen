import XCTest

final class SuperZenUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {}

  @MainActor
  func testExample() throws {
    // SuperZen is a menu-bar-only app; standard UI launch is not applicable.
    throw XCTSkip("SuperZen runs as a menu-bar-only app — no launchable window for UI tests.")
  }
}
