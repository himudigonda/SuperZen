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
  private let saveDelay: Duration
  private let appUsage: AppUsageTracker
  private let logger = Logger(subsystem: "com.himudigonda.SuperZen", category: "Telemetry")

  init(
    recorder: TelemetryRecorder = TelemetryRecorder(),
    saveDelay: Duration = .seconds(30),
    appUsage: AppUsageTracker = AppUsageTracker()
  ) {
    self.recorder = recorder
    self.saveDelay = saveDelay
    self.appUsage = appUsage
  }

  var openActivity: ActivityInterval? { recorder.openInterval }

  func attach(_ context: ModelContext, defaults: UserDefaults = .standard, now: Date = Date()) {
    self.context = context
    appUsage.startObserving()
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
    if defaults.bool(forKey: SettingKey.dataRetentionEnabled) {
      pruneHistoricalData(retainingDays: defaults.integer(forKey: SettingKey.dataRetentionDays), now: now)
    }
    saveNow()
  }

  func record(_ event: TelemetryEvent, at now: Date) {
    let wasOpen = recorder.sessionID != nil
    let records = recorder.record(event, at: now)
    let isOpen = recorder.sessionID != nil
    if wasOpen && !isOpen { store(usage: appUsage.end(at: now)) }
    if !wasOpen && isOpen { appUsage.begin(at: now) }
    store(records)

    switch event {
    case .focusEnded, .breakEnded, .naturalBreak:
      saveNow()
    case .focusStarted, .activeTime, .idleTime, .wellnessEnded:
      scheduleSave()
    }
  }

  func flush() {
    store(recorder.flush())
    saveNow()
  }

  func saveNow() {
    saveTask?.cancel()
    saveTask = nil
    guard let context, context.hasChanges else { return }
    do {
      try context.save()
    } catch {
      logger.error("Telemetry save failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  @discardableResult
  func pruneHistoricalData(retainingDays: Int, now: Date = Date()) -> PruneSummary {
    let cutoff = Calendar.current.date(byAdding: .day, value: -max(1, retainingDays), to: now) ?? now
    return delete(
      activity: #Predicate<ActivityRecordModel> { $0.end < cutoff },
      breaks: #Predicate<BreakRecordModel> { $0.end < cutoff },
      wellness: #Predicate<WellnessRecordModel> { $0.at < cutoff },
      usage: #Predicate<WorkBlockAppUsage> { $0.blockEnd < cutoff })
  }

  @discardableResult
  func clearAllTelemetryData() -> PruneSummary {
    _ = recorder.flush()
    appUsage.reset()
    if recorder.sessionID != nil { appUsage.begin(at: Date()) }
    buffered.removeAll()
    bufferedUsage.removeAll()
    return delete(activity: nil, breaks: nil, wellness: nil, usage: nil)
  }

  private func delete(
    activity: Predicate<ActivityRecordModel>?,
    breaks: Predicate<BreakRecordModel>?,
    wellness: Predicate<WellnessRecordModel>?,
    usage: Predicate<WorkBlockAppUsage>?
  ) -> PruneSummary {
    guard let context else { return .empty }
    do {
      let activityRows = try context.fetch(FetchDescriptor(predicate: activity))
      let breakRows = try context.fetch(FetchDescriptor(predicate: breaks))
      let wellnessRows = try context.fetch(FetchDescriptor(predicate: wellness))
      let usageRows = try context.fetch(FetchDescriptor(predicate: usage))
      activityRows.forEach { context.delete($0) }
      breakRows.forEach { context.delete($0) }
      wellnessRows.forEach { context.delete($0) }
      usageRows.forEach { context.delete($0) }
      saveNow()
      return PruneSummary(
        sessionsDeleted: Set(activityRows.map { $0.sessionID }).count,
        breaksDeleted: breakRows.count,
        wellnessDeleted: wellnessRows.count,
        appUsageDeleted: usageRows.count)
    } catch {
      logger.error("Telemetry delete failed: \(error.localizedDescription, privacy: .public)")
      return .empty
    }
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

  private func observeTermination() {
    guard terminationObserver == nil else { return }
    terminationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.flush() }
    }
  }
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
