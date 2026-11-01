#if canImport(CoreGraphics)
  import CoreGraphics
#endif
import Foundation
import Testing

@testable import SuperZenCore

@Suite struct CursorFollowerTests {
  @Test func easesTowardTheCursor() {
    var follower = CursorFollower(position: .zero, reduceMotion: false)
    let next = follower.step(toward: CGPoint(x: 100, y: -50))
    #expect(next == CGPoint(x: 38, y: -19))
    #expect(follower.position == CGPoint(x: 38, y: -19))
  }

  @Test func reduceMotionSnapsStraightToTheCursor() {
    var follower = CursorFollower(position: .zero, reduceMotion: true)
    #expect(follower.step(toward: CGPoint(x: 100, y: -50)) == CGPoint(x: 100, y: -50))
  }

  @Test func snapsWhenWithinHalfAPoint() {
    var follower = CursorFollower(position: CGPoint(x: 10, y: 10), reduceMotion: false)
    #expect(follower.step(toward: CGPoint(x: 10.3, y: 10.2)) == CGPoint(x: 10.3, y: 10.2))
  }

  @Test func emitsNothingOnceSettled() {
    var follower = CursorFollower(position: CGPoint(x: 5, y: 5), reduceMotion: false)
    #expect(follower.step(toward: CGPoint(x: 5, y: 5)) == nil)
  }

  @Test func convergesWithoutOvershooting() {
    var follower = CursorFollower(position: .zero, reduceMotion: false)
    let target = CGPoint(x: 400, y: 300)
    var steps = 0
    while let point = follower.step(toward: target) {
      #expect(point.x <= target.x && point.y <= target.y)
      steps += 1
      if steps > 100 { break }
    }
    #expect(follower.position == target)
    #expect(steps < 30)
  }

  @Test func jumpMovesWithoutEasing() {
    var follower = CursorFollower(position: .zero, reduceMotion: false)
    follower.jump(to: CGPoint(x: 7, y: 9))
    #expect(follower.position == CGPoint(x: 7, y: 9))
    #expect(follower.step(toward: CGPoint(x: 7, y: 9)) == nil)
  }

  @Test func reduceMotionCanChangeMidFlight() {
    var follower = CursorFollower(position: .zero, reduceMotion: false)
    _ = follower.step(toward: CGPoint(x: 100, y: 0))
    follower.reduceMotion = true
    #expect(follower.step(toward: CGPoint(x: 100, y: 0)) == CGPoint(x: 100, y: 0))
  }
}
