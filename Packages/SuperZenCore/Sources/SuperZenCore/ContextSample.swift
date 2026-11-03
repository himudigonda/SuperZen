import Foundation

public struct ContextSample: Equatable, Sendable {
  public var frontmostBundleID: String?
  public var isMicrophoneInUse: Bool
  public var isFullscreenAppFrontmost: Bool

  public init(
    frontmostBundleID: String? = nil, isMicrophoneInUse: Bool = false, isFullscreenAppFrontmost: Bool = false
  ) {
    self.frontmostBundleID = frontmostBundleID
    self.isMicrophoneInUse = isMicrophoneInUse
    self.isFullscreenAppFrontmost = isFullscreenAppFrontmost
  }

  public static let unknown = ContextSample()
}

public struct DeferralSettings: Codable, Equatable, Sendable {
  public static let maximumCap: TimeInterval = 3600

  public var apps: [String] = []
  public var cap: TimeInterval = 600
  public var recheck: TimeInterval = 15
  public var duringCalls = true
  public var duringFullscreen = false

  public init() {}

  public var isActive: Bool {
    cap > 0 && (!apps.isEmpty || duringCalls || duringFullscreen)
  }

  public func validated() -> DeferralSettings {
    var copy = self
    copy.apps = Array(Set(apps.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
    copy.cap = cap.isNaN ? 0 : min(max(0, cap), Self.maximumCap)
    copy.recheck = recheck.isFinite && recheck >= 1 ? min(recheck, 60) : 15
    return copy
  }

  public static func apps(fromCSV text: String) -> [String] {
    text.split(separator: ",").map(String.init)
  }

  public static func csv(from apps: [String]) -> String {
    apps.joined(separator: ",")
  }
}
