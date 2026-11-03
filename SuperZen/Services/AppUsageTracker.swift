import AppKit
import Foundation
import SuperZenCore

struct AppUsageEntry: Equatable {
  let blockID: UUID
  let blockStart: Date
  let blockEnd: Date
  let appName: String
  let bundleIdentifier: String
  let activeSeconds: Double
  let activationCount: Int
}

@MainActor
final class AppUsageTracker {
  private struct Accumulator {
    var appName: String
    var bundleIdentifier: String
    var activeSeconds: Double
    var activationCount: Int
  }

  private var blockID: UUID?
  private var blockStart: Date?
  private var currentKey: String?
  private var currentStartedAt: Date?
  private var accumulators: [String: Accumulator] = [:]
  private var observer: NSObjectProtocol?

  var isTracking: Bool { blockID != nil }

  func startObserving() {
    guard observer == nil else { return }
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
        return
      }
      let localizedName = app.localizedName
      let bundleIdentifier = app.bundleIdentifier
      MainActor.assumeIsolated {
        guard let self, self.isTracking else { return }
        self.activate(
          name: Self.displayName(localizedName: localizedName), bundleIdentifier: bundleIdentifier, at: Date())
      }
    }
  }

  func begin(at start: Date) {
    begin(at: start, frontmost: NSWorkspace.shared.frontmostApplication)
  }

  func begin(at start: Date, frontmost: NSRunningApplication?) {
    reset()
    blockID = UUID()
    blockStart = start
    if let frontmost {
      activate(name: Self.displayName(of: frontmost), bundleIdentifier: frontmost.bundleIdentifier, at: start)
    }
  }

  func activate(name: String, bundleIdentifier: String?, at timestamp: Date) {
    guard isTracking else { return }
    let bundle = bundleIdentifier ?? name
    let key = bundle.isEmpty ? name : bundle
    guard !key.isEmpty, key != currentKey else { return }
    settleCurrent(until: timestamp)
    currentKey = key
    currentStartedAt = timestamp
    var accumulator =
      accumulators[key] ?? Accumulator(appName: name, bundleIdentifier: bundle, activeSeconds: 0, activationCount: 0)
    accumulator.appName = name
    accumulator.activationCount += 1
    accumulators[key] = accumulator
  }

  func end(at timestamp: Date) -> [AppUsageEntry] {
    defer { reset() }
    settleCurrent(until: timestamp)
    guard let blockID, let blockStart else { return [] }
    return accumulators.values
      .filter { $0.activeSeconds > 0 }
      .sorted { $0.activeSeconds > $1.activeSeconds }
      .map {
        AppUsageEntry(
          blockID: blockID,
          blockStart: blockStart,
          blockEnd: timestamp.clamped(notBefore: blockStart),
          appName: $0.appName,
          bundleIdentifier: $0.bundleIdentifier,
          activeSeconds: $0.activeSeconds,
          activationCount: $0.activationCount)
      }
  }

  func reset() {
    blockID = nil
    blockStart = nil
    currentKey = nil
    currentStartedAt = nil
    accumulators.removeAll()
  }

  private func settleCurrent(until timestamp: Date) {
    guard let key = currentKey, let startedAt = currentStartedAt else { return }
    let delta = timestamp.timeIntervalSince(startedAt)
    guard delta > 0 else { return }
    accumulators[key]?.activeSeconds += delta
    currentStartedAt = timestamp
  }

  private static func displayName(of app: NSRunningApplication) -> String {
    displayName(localizedName: app.localizedName)
  }

  private static func displayName(localizedName: String?) -> String {
    let cleaned = localizedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return cleaned.isEmpty
      ? String(
        localized: "Unknown App",
        comment: "Fallback app name shown in Insights when macOS can't provide a localized app name")
      : cleaned
  }
}
