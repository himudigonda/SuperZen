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

    let window = app.windows.containing(NSPredicate(format: "label == %@", "Skip break")).firstMatch
    XCTAssertLessThan(skip.frame.minY, 200, "the break controls are not at the top of the screen")
    XCTAssertLessThan(window.frame.height, 200, "the break window is \(window.frame), not a banner")

    app.open(try XCTUnwrap(URL(string: "superzen://skip")))
    let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: skip)
    wait(for: [gone], timeout: 10)
  }
}
