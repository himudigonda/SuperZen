@MainActor
public protocol ActivityMonitoring: AnyObject {
  func sample() -> ActivitySample
}

