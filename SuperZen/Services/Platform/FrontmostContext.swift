import AppKit
import SuperZenCore

@MainActor
protocol ContextProviding {
  func sample() -> ContextSample
}

@MainActor
struct FrontmostContext: ContextProviding {
  func sample() -> ContextSample {
    ContextSample(frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
  }
}
