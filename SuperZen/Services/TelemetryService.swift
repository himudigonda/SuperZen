import AppKit
import Foundation
import OSLog
import SuperZenCore
import SwiftData

@MainActor
final class TelemetryService {
  static let shared = TelemetryService()

  struct PruneSummary: Equatable {
    let sessionsDeleted: Int
    let breaksDeleted: Int
    let wellnessDeleted: Int
    let appUsageDeleted: Int

    static let empty = PruneSummary(sessionsDeleted: 0, breaksDeleted: 0, wellnessDeleted: 0, appUsageDeleted: 0)

    var totalDeleted: Int {
      sessionsDeleted + breaksDeleted + wellnessDeleted + appUsageDeleted
    }
  }

  private(set) var context: ModelContext?
  private var recorder: TelemetryRecorder
  private var buffered: [TelemetryRecord] = []
  private var bufferedUsage: [AppUsageEntry] = []
  private var saveTask: Task<Void, Never>?
  private var terminationObserver: NSObjectProtocol?
  private var retentionDefaults: UserDefaults?
  private var defaultsObserver: NSObjectProtocol?
  private var usageTrackingActive = false
  private var lastPruneDay: Date?
  private let saveDelay: Duration
  private let appUsage: AppUsageTracker
  private let notificationCenter: NotificationCenter
  private let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "Telemetry")

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

  private func pruneIfNewDay(at now: Date) {
    guard context != nil, let defaults = retentionDefaults else { return }
    let day = Calendar.current.startOfDay(for: now)
    guard day != lastPruneDay else { return }
    lastPruneDay = day
    guard defaults.bool(forKey: SettingKey.dataRetentionEnabled) else { return }
    pruneHistoricalData(retainingDays: defaults.integer(forKey: SettingKey.dataRetentionDays), now: now)
  }

  @discardableResult
  func pruneHistoricalData(retainingDays: Int, now: Date = Date()) -> PruneSummary {
    let cutoff = Calendar.current.date(byAdding: .day, value: -max(1, retainingDays), to: now) ?? now
    do {
      let summary = try delete(
        activity: #Predicate<ActivityRecordModel> { $0.end < cutoff },
        breaks: #Predicate<BreakRecordModel> { $0.end < cutoff },
        wellness: #Predicate<WellnessRecordModel> { $0.at < cutoff },
        usage: #Predicate<WorkBlockAppUsage> { $0.blockEnd < cutoff })
      if summary.totalDeleted > 0 { notifyChange() }
      return summary
    } catch {
      logger.error("Telemetry prune failed: \(error.localizedDescription, privacy: .public)")
      return .empty
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

  private func delete(
    activity: Predicate<ActivityRecordModel>?,
    breaks: Predicate<BreakRecordModel>?,
    wellness: Predicate<WellnessRecordModel>?,
    usage: Predicate<WorkBlockAppUsage>?
  ) throws -> PruneSummary {
    guard let context else { return .empty }
    saveNow()
    do {
      let activityRows = try context.fetch(FetchDescriptor(predicate: activity))
      let breakRows = try context.fetch(FetchDescriptor(predicate: breaks))
      let wellnessRows = try context.fetch(FetchDescriptor(predicate: wellness))
      let usageRows = try context.fetch(FetchDescriptor(predicate: usage))
      activityRows.forEach { context.delete($0) }
      breakRows.forEach { context.delete($0) }
      wellnessRows.forEach { context.delete($0) }
      usageRows.forEach { context.delete($0) }
      if context.hasChanges { try context.save() }
      return PruneSummary(
        sessionsDeleted: Set(activityRows.map { $0.sessionID }).count,
        breaksDeleted: breakRows.count,
        wellnessDeleted: wellnessRows.count,
        appUsageDeleted: usageRows.count)
    } catch {
      context.rollback()
      throw error
    }
  }

  private func notifyChange() {
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
