import AppKit
import SuperZenCore

@MainActor
protocol ContextProviding {
  func sample(for settings: DeferralSettings) -> ContextSample
}

struct ExpiringProbe<Key: Equatable> {
  let lifetime: TimeInterval
  private var key: Key?
  private var value = false
  private var probedAt = Date.distantPast

  init(lifetime: TimeInterval) {
    self.lifetime = lifetime
  }

  mutating func value(for key: Key, at now: Date, probe: () -> Bool) -> Bool {
    let age = now.timeIntervalSince(probedAt)
    if self.key == key, age >= 0, age < lifetime { return value }
    value = probe()
    self.key = key
    probedAt = now
    return value
  }

  mutating func invalidate() {
    key = nil
  }
}

extension ExpiringProbe where Key == Bool {
  mutating func value(at now: Date, probe: () -> Bool) -> Bool {
    value(for: true, at: now, probe: probe)
  }
}

@MainActor
final class FrontmostContext: ContextProviding {
  static let probeLifetime: TimeInterval = 5

  private let clock: any WallClock
  private let frontmost: @MainActor () -> (bundleID: String?, pid: pid_t?)
  private let microphone: @MainActor () -> Bool
  private let fullscreen: @MainActor (pid_t) -> Bool
  private var microphoneProbe = ExpiringProbe<Bool>(lifetime: FrontmostContext.probeLifetime)
  private var fullscreenProbe = ExpiringProbe<pid_t>(lifetime: FrontmostContext.probeLifetime)

  init(
    clock: any WallClock = SystemClock(),
    frontmost: @escaping @MainActor () -> (bundleID: String?, pid: pid_t?) = FrontmostContext.workspaceFrontmost,
    microphone: @escaping @MainActor () -> Bool = MicrophoneActivity.isAnyInputRunning,
    fullscreen: @escaping @MainActor (pid_t) -> Bool = FullscreenDetector.hasFullscreenWindow(ownedBy:)
  ) {
    self.clock = clock
    self.frontmost = frontmost
    self.microphone = microphone
    self.fullscreen = fullscreen
  }

  func sample(for settings: DeferralSettings) -> ContextSample {
    let app = frontmost()
    let now = clock.now
    var sample = ContextSample(frontmostBundleID: app.bundleID)
    guard settings.isActive else {
      microphoneProbe.invalidate()
      fullscreenProbe.invalidate()
      return sample
    }
    if settings.duringCalls {
      sample.isMicrophoneInUse = microphoneProbe.value(at: now, probe: microphone)
    } else {
      microphoneProbe.invalidate()
    }
    if settings.duringFullscreen, let pid = app.pid, pid != ProcessInfo.processInfo.processIdentifier {
      sample.isFullscreenAppFrontmost = fullscreenProbe.value(for: pid, at: now) { fullscreen(pid) }
    } else {
      fullscreenProbe.invalidate()
    }
    return sample
  }

  static func workspaceFrontmost() -> (bundleID: String?, pid: pid_t?) {
    let app = NSWorkspace.shared.frontmostApplication
    return (app?.bundleIdentifier, app?.processIdentifier)
  }
}
