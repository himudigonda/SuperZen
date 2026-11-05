import Foundation
import OSLog
import SwiftData

extension TelemetryService {
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

  func pruneIfNewDay(at now: Date) {
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

  func delete(
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
}
