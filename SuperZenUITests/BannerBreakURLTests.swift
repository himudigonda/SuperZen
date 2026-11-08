import XCTest

final class BannerBreakURLTests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testStartBreakLinkShowsBannerAndSkipLinkClosesIt() throws {
    let app = XCUIApplication()
    app.launchArguments += [
      "-hasCompletedOnboarding", "YES",
      "-breakPresentation", "banner",
      "-difficulty", "Casual",
    ]
    app.launch()
    defer { app.terminate() }

    let skip = app.buttons["Skip break"]
    XCTAssertFalse(skip.exists, "a break was showing before the link was opened")

    app.open(try XCTUnwrap(URL(string: "superzen://start-break")))
    XCTAssertTrue(skip.waitForExistence(timeout: 10), "superzen://start-break did not show a break")

    XCTAssertLessThan(skip.frame.minY, 200, "skip is at \(skip.frame), not in a banner at the top of the screen")

    app.open(try XCTUnwrap(URL(string: "superzen://skip")))
    let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: skip)
    wait(for: [gone], timeout: 10)
  }
}
