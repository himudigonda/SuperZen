import Foundation

public struct ContextSample: Equatable, Sendable {
  public var frontmostBundleID: String?

  public init(frontmostBundleID: String? = nil) {
    self.frontmostBundleID = frontmostBundleID
  }

  public static let unknown = ContextSample()
}

public struct DeferralSettings: Codable, Equatable, Sendable {
  public static let maximumCap: TimeInterval = 3600

  public var apps: [String] = []
  public var cap: TimeInterval = 600
  public var recheck: TimeInterval = 15

  public init() {}

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
