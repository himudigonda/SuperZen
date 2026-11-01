#if canImport(CoreGraphics)
  import CoreGraphics
#endif
import Foundation

public struct CursorFollower: Equatable, Sendable {
  public static let smoothing: CGFloat = 0.38
  public static let snapDistance: CGFloat = 0.5

  public private(set) var position: CGPoint
  public var reduceMotion: Bool

  public init(position: CGPoint, reduceMotion: Bool) {
    self.position = position
    self.reduceMotion = reduceMotion
  }

  public mutating func step(toward target: CGPoint) -> CGPoint? {
    guard position != target else { return nil }
    let dx = target.x - position.x
    let dy = target.y - position.y
    if reduceMotion || hypot(dx, dy) < Self.snapDistance {
      position = target
    } else {
      position = CGPoint(x: position.x + dx * Self.smoothing, y: position.y + dy * Self.smoothing)
    }
    return position
  }

  public mutating func jump(to target: CGPoint) {
    position = target
  }
}
