import Foundation
import Testing

@testable import SuperZenCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

@Suite struct OverlayGeometryTests {
  private let laptop = ScreenArea(
    frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
    visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))
  private let external = ScreenArea(
    frame: CGRect(x: 1440, y: 0, width: 2560, height: 1440),
    visibleFrame: CGRect(x: 1440, y: 0, width: 2560, height: 1415))

  @Test func nudgeSitsBesideTheCursor() {
    let origin = OverlayGeometry.nudgeOrigin(cursor: CGPoint(x: 400, y: 400), screens: [laptop])
    #expect(origin == CGPoint(x: 422, y: 342))
  }

  @Test func nudgeIsClampedInsideTheCursorScreen() {
    let corner = OverlayGeometry.nudgeOrigin(
      cursor: CGPoint(x: 1435, y: 20), screens: [laptop, external])
    #expect(corner == CGPoint(x: 1440 - 210, y: 0))
    let onExternal = OverlayGeometry.nudgeOrigin(
      cursor: CGPoint(x: 3990, y: 1400), screens: [laptop, external])
    #expect(onExternal == CGPoint(x: 4000 - 210, y: 1342))
  }

  @Test func nudgeWithoutScreensFollowsCursorUnclamped() {
    let origin = OverlayGeometry.nudgeOrigin(cursor: CGPoint(x: -50, y: 10), screens: [])
    #expect(origin == CGPoint(x: -28, y: -48))
  }

  @Test func alertKeepsTheCardFortyPointsFromTheEdges() {
    let frame = laptop.visibleFrame
    let size = OverlayGeometry.alertWindowSize
    let left = OverlayGeometry.alertOrigin(placement: .left, in: frame)
    let right = OverlayGeometry.alertOrigin(placement: .right, in: frame)
    let center = OverlayGeometry.alertOrigin(placement: .center, in: frame)
    #expect(left.x + OverlayGeometry.alertInset.width == 40)
    #expect(frame.maxX - (right.x + size.width - OverlayGeometry.alertInset.width) == 40)
    #expect(center.x + size.width / 2 == frame.midX)
    #expect(frame.maxY - (left.y + size.height - OverlayGeometry.alertInset.height) == 40)
  }

  @Test func unknownPlacementFallsBackToCenter() {
    #expect(AlertPlacement(setting: "top") == .center)
    #expect(AlertPlacement(setting: "left") == .left)
  }

  @Test func bannerSitsAtTopCentreBelowTheMenuBar() {
    let frame = laptop.visibleFrame
    let size = OverlayGeometry.bannerWindowSize
    let origin = OverlayGeometry.bannerOrigin(in: frame)
    #expect(origin.x + size.width / 2 == frame.midX)
    let cardTop = origin.y + size.height - OverlayGeometry.bannerInset.height
    #expect(frame.maxY - cardTop == OverlayGeometry.bannerScreenPadding)
  }

  @Test func bannerStaysInsideATinyScreen() {
    let tiny = CGRect(x: 100, y: 50, width: 200, height: 60)
    let origin = OverlayGeometry.bannerOrigin(in: tiny)
    #expect(origin.x == tiny.minX)
    #expect(origin.y == tiny.minY)
  }
}
