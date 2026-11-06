import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public struct ScreenArea: Equatable, Sendable {
  public var frame: CGRect
  public var visibleFrame: CGRect

  public init(frame: CGRect, visibleFrame: CGRect) {
    self.frame = frame
    self.visibleFrame = visibleFrame
  }
}

public enum AlertPlacement: String, CaseIterable, Sendable {
  case left
  case center
  case right

  public init(setting: String) {
    self = AlertPlacement(rawValue: setting) ?? .center
  }
}

public enum OverlayGeometry {
  public static let nudgeSize = CGSize(width: 210, height: 54)
  public static let nudgeOffset = CGPoint(x: 22, y: -58)
  public static let alertCardSize = CGSize(width: 420, height: 200)
  public static let alertInset = CGSize(width: 30, height: 40)
  public static let alertScreenPadding: CGFloat = 40
  public static let bannerCardSize = CGSize(width: 460, height: 72)
  public static let bannerInset = CGSize(width: 24, height: 16)
  public static let bannerScreenPadding: CGFloat = 16

  public static var alertWindowSize: CGSize {
    CGSize(
      width: alertCardSize.width + alertInset.width * 2,
      height: alertCardSize.height + alertInset.height * 2)
  }

  public static var bannerWindowSize: CGSize {
    CGSize(
      width: bannerCardSize.width + bannerInset.width * 2,
      height: bannerCardSize.height + bannerInset.height * 2)
  }

  public static func bannerOrigin(in visibleFrame: CGRect) -> CGPoint {
    let size = bannerWindowSize
    let target = CGPoint(
      x: visibleFrame.midX - size.width / 2,
      y: visibleFrame.maxY - size.height - (bannerScreenPadding - bannerInset.height))
    return clamp(target, size: size, into: visibleFrame)
  }

  public static func nudgeOrigin(cursor: CGPoint, screens: [ScreenArea]) -> CGPoint {
    let target = CGPoint(x: cursor.x + nudgeOffset.x, y: cursor.y + nudgeOffset.y)
    guard let area = screens.first(where: { $0.frame.contains(cursor) }) ?? screens.first else {
      return target
    }
    return clamp(target, size: nudgeSize, into: area.visibleFrame)
  }

  public static func alertOrigin(placement: AlertPlacement, in visibleFrame: CGRect) -> CGPoint {
    let size = alertWindowSize
    let x: CGFloat
    switch placement {
    case .left:
      x = visibleFrame.minX + alertScreenPadding - alertInset.width
    case .center:
      x = visibleFrame.midX - size.width / 2
    case .right:
      x = visibleFrame.maxX - size.width - (alertScreenPadding - alertInset.width)
    }
    let y = visibleFrame.maxY - size.height - (alertScreenPadding - alertInset.height)
    return CGPoint(x: x, y: y)
  }

  static func clamp(_ point: CGPoint, size: CGSize, into frame: CGRect) -> CGPoint {
    CGPoint(
      x: min(max(point.x, frame.minX), max(frame.minX, frame.maxX - size.width)),
      y: min(max(point.y, frame.minY), max(frame.minY, frame.maxY - size.height)))
  }
}
