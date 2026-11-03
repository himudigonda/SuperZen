import Foundation

public enum ExportFormat: String, CaseIterable, Sendable {
  case csv
  case json

  public var fileExtension: String { rawValue }
}

public enum ExportDataset: String, CaseIterable, Sendable {
  case breaks
  case wellness
  case focusSessions

  public var fileStem: String {
    switch self {
    case .breaks: return "superzen-breaks"
    case .wellness: return "superzen-wellness"
    case .focusSessions: return "superzen-focus-sessions"
    }
  }

  public var columns: [String] {
    switch self {
    case .breaks: return ["kind", "result", "start", "end", "planned_seconds", "rested_seconds"]
    case .wellness: return ["kind", "at", "completed"]
    case .focusSessions: return ["session_id", "kind", "start", "end", "duration_seconds"]
    }
  }
}

public enum CSVEncoding {
  public static let lineEnding = "\r\n"
  private static let formulaPrefixes: Set<Unicode.Scalar> = ["=", "+", "-", "@", "\t", "\r"]
  private static let quotingScalars: Set<Unicode.Scalar> = [",", "\"", "\r", "\n"]

  public static func field(_ text: String) -> String {
    let guarded = text.unicodeScalars.first.map { formulaPrefixes.contains($0) } == true
    let needsQuotes = guarded || text.unicodeScalars.contains(where: { quotingScalars.contains($0) })
    guard needsQuotes else { return text }
    let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
    return "\"" + (guarded ? "'" : "") + escaped + "\""
  }

  public static func row(_ fields: [String]) -> String {
    fields.map(field).joined(separator: ",") + lineEnding
  }
}

public struct InsightsExport: Sendable {
  public let timeZone: TimeZone

  public init(timeZone: TimeZone = .current) {
    self.timeZone = timeZone
  }

  public func render(_ dataset: ExportDataset, format: ExportFormat, from snapshot: TelemetrySnapshot) -> String {
    switch (dataset, format) {
    case (.breaks, .csv): return breaksCSV(snapshot.breaks)
    case (.breaks, .json): return breaksJSON(snapshot.breaks)
    case (.wellness, .csv): return wellnessCSV(snapshot.wellness)
    case (.wellness, .json): return wellnessJSON(snapshot.wellness)
    case (.focusSessions, .csv): return focusSessionsCSV(snapshot.activity)
    case (.focusSessions, .json): return focusSessionsJSON(snapshot.activity)
    }
  }

  public func fileName(for dataset: ExportDataset, format: ExportFormat) -> String {
    dataset.fileStem + "." + format.fileExtension
  }

  public func breaksCSV(_ records: [BreakRecord]) -> String {
    csv(.breaks, rows: ordered(records).map(breakFields))
  }

  public func wellnessCSV(_ records: [WellnessRecord]) -> String {
    csv(.wellness, rows: ordered(records).map(wellnessFields))
  }

  public func focusSessionsCSV(_ intervals: [ActivityInterval]) -> String {
    csv(.focusSessions, rows: ordered(intervals).map(focusFields))
  }

  public func breaksJSON(_ records: [BreakRecord]) -> String {
    json(
      ordered(records).map { record in
        [
          "kind": .text(record.kind.rawValue),
          "result": .text(record.result.rawValue),
          "start": .text(timestamp(record.start)),
          "end": .text(timestamp(record.end)),
          "planned_seconds": .number(seconds(record.planned)),
          "rested_seconds": .number(seconds(record.rested)),
        ]
      })
  }

  public func wellnessJSON(_ records: [WellnessRecord]) -> String {
    json(
      ordered(records).map { record in
        [
          "kind": .text(record.kind.rawValue),
          "at": .text(timestamp(record.at)),
          "completed": .flag(record.completed),
        ]
      })
  }

  public func focusSessionsJSON(_ intervals: [ActivityInterval]) -> String {
    json(
      ordered(intervals).map { interval in
        [
          "session_id": .text(interval.sessionID.uuidString),
          "kind": .text(interval.kind.rawValue),
          "start": .text(timestamp(interval.start)),
          "end": .text(timestamp(interval.end)),
          "duration_seconds": .number(seconds(interval.duration)),
        ]
      })
  }

  public func timestamp(_ date: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    let offsetMinutes = timeZone.secondsFromGMT(for: date) / 60
    let magnitude = abs(offsetMinutes)
    return [
      Self.padded(parts.year ?? 0, 4), "-", Self.padded(parts.month ?? 0, 2), "-", Self.padded(parts.day ?? 0, 2),
      "T", Self.padded(parts.hour ?? 0, 2), ":", Self.padded(parts.minute ?? 0, 2), ":",
      Self.padded(parts.second ?? 0, 2), offsetMinutes < 0 ? "-" : "+", Self.padded(magnitude / 60, 2), ":",
      Self.padded(magnitude % 60, 2),
    ].joined()
  }

  private enum JSONValue: Encodable {
    case text(String)
    case number(Int)
    case flag(Bool)

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .text(let value): try container.encode(value)
      case .number(let value): try container.encode(value)
      case .flag(let value): try container.encode(value)
      }
    }
  }

  private func csv(_ dataset: ExportDataset, rows: [[String]]) -> String {
    CSVEncoding.row(dataset.columns) + rows.map(CSVEncoding.row).joined()
  }

  private func json(_ rows: [[String: JSONValue]]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(rows), let text = String(data: data, encoding: .utf8) else { return "[]" }
    return text
  }

  private func breakFields(_ record: BreakRecord) -> [String] {
    [
      record.kind.rawValue, record.result.rawValue, timestamp(record.start), timestamp(record.end),
      String(seconds(record.planned)), String(seconds(record.rested)),
    ]
  }

  private func wellnessFields(_ record: WellnessRecord) -> [String] {
    [record.kind.rawValue, timestamp(record.at), record.completed ? "true" : "false"]
  }

  private func focusFields(_ interval: ActivityInterval) -> [String] {
    [
      interval.sessionID.uuidString, interval.kind.rawValue, timestamp(interval.start), timestamp(interval.end),
      String(seconds(interval.duration)),
    ]
  }

  private func ordered(_ records: [BreakRecord]) -> [BreakRecord] {
    records.sorted { lhs, rhs in
      if lhs.start != rhs.start { return lhs.start < rhs.start }
      if lhs.end != rhs.end { return lhs.end < rhs.end }
      if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
      if lhs.result != rhs.result { return lhs.result.rawValue < rhs.result.rawValue }
      return lhs.planned < rhs.planned
    }
  }

  private func ordered(_ records: [WellnessRecord]) -> [WellnessRecord] {
    records.sorted { lhs, rhs in
      if lhs.at != rhs.at { return lhs.at < rhs.at }
      if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
      return !lhs.completed && rhs.completed
    }
  }

  private func ordered(_ intervals: [ActivityInterval]) -> [ActivityInterval] {
    intervals.sorted { lhs, rhs in
      if lhs.start != rhs.start { return lhs.start < rhs.start }
      if lhs.end != rhs.end { return lhs.end < rhs.end }
      if lhs.sessionID != rhs.sessionID { return lhs.sessionID.uuidString < rhs.sessionID.uuidString }
      return lhs.kind.rawValue < rhs.kind.rawValue
    }
  }

  private func seconds(_ interval: TimeInterval) -> Int {
    Int.saturating(interval.rounded())
  }

  private static func padded(_ value: Int, _ width: Int) -> String {
    let digits = String(abs(value))
    let zeros = String(repeating: "0", count: max(0, width - digits.count))
    return (value < 0 ? "-" : "") + zeros + digits
  }
}
