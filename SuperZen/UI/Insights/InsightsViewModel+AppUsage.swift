import Foundation
import SuperZenCore

extension InsightsViewModel {
  static func topApps(from usage: [AppUsageSample]) -> [TopAppSummary] {
    Dictionary(grouping: usage, by: \.appName)
      .map { appName, rows in
        TopAppSummary(
          id: appName,
          appName: appName,
          activeMinutes: Int(saturating: rows.reduce(0.0) { $0 + $1.activeSeconds } / 60),
          activationCount: rows.reduce(0) { $0 + $1.activationCount })
      }
      .sorted { ($0.activeMinutes, $0.activationCount) > ($1.activeMinutes, $1.activationCount) }
      .prefix(8)
      .map { $0 }
  }

  static func workBlocks(from usage: [AppUsageSample]) -> [WorkBlockAppSummary] {
    let blocks = Dictionary(grouping: usage, by: \.blockID)
      .compactMap { blockID, rows in summarize(blockID: blockID, rows: rows) }
      .sorted { $0.blockStart < $1.blockStart }
    return blocks.enumerated().map { index, block in
      WorkBlockAppSummary(
        id: block.id,
        label: String(localized: "Work block \(index + 1)", comment: "Insights: numbered work block name"),
        blockStart: block.blockStart,
        timeWindow: block.timeWindow,
        totalMinutes: block.totalMinutes,
        uniqueAppCount: block.uniqueAppCount,
        rows: block.rows)
    }
  }

  private static func summarize(blockID: UUID, rows: [AppUsageSample]) -> WorkBlockAppSummary? {
    guard let blockStart = rows.map(\.blockStart).min(), let blockEnd = rows.map(\.blockEnd).max() else { return nil }
    let totalSeconds = rows.reduce(0.0) { $0 + $1.activeSeconds }
    guard totalSeconds > 0 else { return nil }
    let appRows = Dictionary(grouping: rows, by: \.appName)
      .map { appName, values in
        let seconds = values.reduce(0.0) { $0 + $1.activeSeconds }
        return WorkBlockAppRow(
          id: "\(blockID.uuidString)-\(values.first?.bundleIdentifier ?? appName)",
          appName: appName,
          activeMinutes: Int(saturating: seconds / 60),
          activationCount: values.reduce(0) { $0 + $1.activationCount },
          share: seconds / totalSeconds)
      }
      .sorted { ($0.activeMinutes, $0.activationCount) > ($1.activeMinutes, $1.activationCount) }
    return WorkBlockAppSummary(
      id: blockID,
      label: "",
      blockStart: blockStart,
      timeWindow:
        "\(blockStart.formatted(.dateTime.hour().minute())) to \(blockEnd.formatted(.dateTime.hour().minute()))",
      totalMinutes: Int(saturating: totalSeconds / 60),
      uniqueAppCount: appRows.count,
      rows: Array(appRows.prefix(5)))
  }
}
