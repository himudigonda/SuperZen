import AppKit
import Foundation
import OSLog
import SuperZenCore
import SwiftData

@MainActor
final class TelemetryService {
  static let shared = TelemetryService()

  private(set) var context: ModelContext?
  private var recorder: TelemetryRecorder
  private var buffered: [TelemetryRecord] = []
  private var bufferedUsage: [AppUsageEntry] = []
  private var saveTask: Task<Void, Never>?
  private var terminationObserver: NSObjectProtocol?
  var retentionDefaults: UserDefaults?
  private var defaultsObserver: NSObjectProtocol?
  private var usageTrackingActive = false
  var lastPruneDay: Date?
  private let saveDelay: Duration
  private let appUsage: AppUsageTracker
  private let notificationCenter: NotificationCenter
  let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "Telemetry")

  init(
    recorder: TelemetryRecorder = TelemetryRecorder(),
    saveDelay: Duration = .seconds(30),
    appUsage: AppUsageTracker? = nil,
    notificationCenter: NotificationCenter = .default
  ) {
    self.recorder = recorder
    self.saveDelay = saveDelay
    self.appUsage = appUsage ?? AppUsageTracker()
    self.notificationCenter = notificationCenter
  }

  var openActivity: ActivityInterval? { recorder.openInterval }

  func attach(_ context: ModelContext, defaults: UserDefaults = .standard, now: Date = Date()) {
    self.context = context
    retentionDefaults = defaults
    refreshUsageTracking(at: now)
    observeUsageTrackingSetting(in: defaults)
    observeTermination()
    do {
      let imported = try LegacyTelemetryImporter.run(in: context)
      if imported > 0 { logger.notice("Imported \(imported) legacy telemetry records") }
    } catch {
      logger.error("Legacy telemetry import failed: \(error.localizedDescription, privacy: .public)")
    }
    buffered.forEach(context.insertRecord)
    bufferedUsage.forEach { context.insert(WorkBlockAppUsage.make($0)) }
    buffered.removeAll()
    bufferedUsage.removeAll()
    pruneIfNewDay(at: now)
    saveNow()
  }

  func refreshUsageTracking(at now: Date) {
    let enabled = (retentionDefaults ?? .standard).object(forKey: SettingKey.appUsageTrackingEnabled) as? Bool ?? true
    guard enabled != usageTrackingActive else { return }
    usageTrackingActive = enabled
    if enabled {
      appUsage.startObserving()
      if recorder.sessionID != nil, !appUsage.isTracking { appUsage.begin(at: now) }
    } else {
      appUsage.stopObserving()
      appUsage.reset()
    }
  }

  func record(_ event: TelemetryEvent, at now: Date) {
    let wasOpen = recorder.sessionID != nil
    let records = recorder.record(event, at: now)
    let isOpen = recorder.sessionID != nil
    if wasOpen && !isOpen { store(usage: appUsage.end(at: now)) }
    if !wasOpen && isOpen && usageTrackingActive { appUsage.begin(at: now) }
    store(records)
    pruneIfNewDay(at: now)

    switch event {
    case .focusEnded, .breakEnded, .naturalBreak:
      saveNow()
    case .focusStarted, .activeTime, .idleTime, .wellnessEnded:
      scheduleSave()
    }
  }

  func flush(at now: Date = Date()) {
    if recorder.sessionID != nil { store(usage: appUsage.end(at: now)) }
    store(recorder.flush())
    saveNow()
  }

  func saveNow() {
    saveTask?.cancel()
    saveTask = nil
    guard let context, context.hasChanges else { return }
    do {
      try context.save()
      notifyChange()
    } catch {
      logger.error("Telemetry save failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  @discardableResult
  func clearAllTelemetryData() throws -> PruneSummary {
    let summary = try delete(activity: nil, breaks: nil, wellness: nil, usage: nil)
    _ = recorder.flush()
    appUsage.reset()
    if recorder.sessionID != nil && usageTrackingActive { appUsage.begin(at: Date()) }
    buffered.removeAll()
    bufferedUsage.removeAll()
    notifyChange()
    return summary
  }

  func notifyChange() {
    notificationCenter.post(name: .superZenTelemetryDidChange, object: self)
  }

  private func store(_ records: [TelemetryRecord]) {
    guard !records.isEmpty else { return }
    guard let context else {
      buffered += records
      return
    }
    records.forEach(context.insertRecord)
  }

  private func store(usage entries: [AppUsageEntry]) {
    guard !entries.isEmpty else { return }
    guard let context else {
      bufferedUsage += entries
      return
    }
    entries.forEach { context.insert(WorkBlockAppUsage.make($0)) }
  }

  private func scheduleSave() {
    guard saveTask == nil, context != nil else { return }
    let delay = saveDelay
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled, let self else { return }
      self.saveTask = nil
      self.saveNow()
    }
  }

  private func observeUsageTrackingSetting(in defaults: UserDefaults) {
    if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
    defaultsObserver = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification, object: defaults, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshUsageTracking(at: Date()) }
    }
  }

  private func observeTermination() {
    guard terminationObserver == nil else { return }
    terminationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.flush() }
    }
  }
}

extension Notification.Name {
  nonisolated static let superZenTelemetryDidChange = Notification.Name("com.himudigonda.SuperZen.telemetryDidChange")
}

extension WorkBlockAppUsage {
  static func make(_ entry: AppUsageEntry) -> WorkBlockAppUsage {
    WorkBlockAppUsage(
      blockID: entry.blockID,
      blockStart: entry.blockStart,
      blockEnd: entry.blockEnd,
      appName: entry.appName,
      bundleIdentifier: entry.bundleIdentifier,
      activeSeconds: entry.activeSeconds,
      activationCount: entry.activationCount)
  }
}
