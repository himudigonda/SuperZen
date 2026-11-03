import Foundation
import Testing

@testable import SuperZenCore

private let utcExport = InsightsExport(timeZone: TimeZone(identifier: "UTC")!)
private let newYorkExport = InsightsExport(timeZone: TimeZone(identifier: "America/New_York")!)
private let sessionOne = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
private let sessionTwo = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

private func breakRecord(
  _ kind: BreakKind = .short, _ result: BreakResult = .completed, at start: Date, seconds: TimeInterval = 20,
  planned: TimeInterval = 20
) -> BreakRecord {
  BreakRecord(kind: kind, result: result, start: start, end: start.addingTimeInterval(seconds), planned: planned)
}

@Suite struct InsightsExportTests {
  @Test func breaksCSVMatchesExactBytes() {
    let records = [
      breakRecord(.short, .completed, at: utcDate(2026, 11, 2, 12)),
      breakRecord(.long, .skipped, at: utcDate(2026, 11, 2, 13, 30, 5), seconds: 45, planned: 300),
    ]
    let expected =
      "kind,result,start,end,planned_seconds,rested_seconds\r\n"
      + "short,completed,2026-11-02T12:00:00+00:00,2026-11-02T12:00:20+00:00,20,20\r\n"
      + "long,skipped,2026-11-02T13:30:05+00:00,2026-11-02T13:30:50+00:00,300,45\r\n"
    #expect(utcExport.breaksCSV(records) == expected)
    #expect(Array(utcExport.breaksCSV(records).utf8) == Array(expected.utf8))
  }

  @Test func wellnessCSVMatchesExactBytes() {
    let records = [
      WellnessRecord(kind: .water, at: utcDate(2026, 11, 2, 10), completed: false),
      WellnessRecord(kind: .posture, at: utcDate(2026, 11, 2, 9), completed: true),
    ]
    let expected =
      "kind,at,completed\r\n"
      + "posture,2026-11-02T09:00:00+00:00,true\r\n"
      + "water,2026-11-02T10:00:00+00:00,false\r\n"
    #expect(utcExport.wellnessCSV(records) == expected)
  }

  @Test func focusSessionsCSVMatchesExactBytes() {
    let start = utcDate(2026, 11, 2, 9)
    let intervals = [
      ActivityInterval(sessionID: sessionOne, kind: .active, start: start, end: start.addingTimeInterval(1500)),
      ActivityInterval(
        sessionID: sessionOne, kind: .idle, start: start.addingTimeInterval(1500), end: start.addingTimeInterval(1560)),
    ]
    let expected =
      "session_id,kind,start,end,duration_seconds\r\n"
      + "00000000-0000-0000-0000-00000000000A,active,2026-11-02T09:00:00+00:00,2026-11-02T09:25:00+00:00,1500\r\n"
      + "00000000-0000-0000-0000-00000000000A,idle,2026-11-02T09:25:00+00:00,2026-11-02T09:26:00+00:00,60\r\n"
    #expect(utcExport.focusSessionsCSV(intervals) == expected)
  }

  @Test func emptyInputYieldsOnlyTheHeader() {
    #expect(utcExport.breaksCSV([]) == "kind,result,start,end,planned_seconds,rested_seconds\r\n")
    #expect(utcExport.wellnessCSV([]) == "kind,at,completed\r\n")
    #expect(utcExport.focusSessionsCSV([]) == "session_id,kind,start,end,duration_seconds\r\n")
    #expect(utcExport.breaksJSON([]) == "[]")
    #expect(utcExport.wellnessJSON([]) == "[]")
    #expect(utcExport.focusSessionsJSON([]) == "[]")
  }

  @Test func everyLineEndsWithCRLFAndNeverBareLF() {
    let text = utcExport.breaksCSV([
      breakRecord(at: utcDate(2026, 11, 2, 12)), breakRecord(at: utcDate(2026, 11, 2, 13)),
    ])
    let bytes = Array(text.utf8)
    for (index, byte) in bytes.enumerated() where byte == 0x0A {
      #expect(index > 0 && bytes[index - 1] == 0x0D)
    }
    #expect(text.hasSuffix("\r\n"))
    #expect(bytes.filter { $0 == 0x0A }.count == 3)
  }

  @Test func orderingIsDeterministicWhateverTheInputOrder() {
    let start = utcDate(2026, 11, 2, 12)
    let records = [
      breakRecord(.long, .skipped, at: start),
      breakRecord(.short, .completed, at: start),
      breakRecord(.short, .skipped, at: start),
      breakRecord(.short, .completed, at: start.addingTimeInterval(-60)),
      breakRecord(.short, .completed, at: start, seconds: 10),
    ]
    let reference = utcExport.breaksCSV(records)
    #expect(utcExport.breaksCSV(records.reversed()) == reference)
    #expect(utcExport.breaksCSV(records.shuffled()) == reference)
    #expect(utcExport.breaksJSON(records.reversed()) == utcExport.breaksJSON(records))
    let firstDataLine = reference.split(separator: "\r\n")[1]
    #expect(firstDataLine.contains("2026-11-02T11:59:00+00:00"))
  }

  @Test func wellnessAndFocusOrderingIgnoresInputOrder() {
    let at = utcDate(2026, 11, 2, 9)
    let wellness = [
      WellnessRecord(kind: .water, at: at, completed: true),
      WellnessRecord(kind: .blink, at: at, completed: true),
      WellnessRecord(kind: .blink, at: at, completed: false),
    ]
    #expect(utcExport.wellnessCSV(wellness) == utcExport.wellnessCSV(wellness.reversed()))
    let intervals = [
      ActivityInterval(sessionID: sessionTwo, kind: .active, start: at, end: at.addingTimeInterval(60)),
      ActivityInterval(sessionID: sessionOne, kind: .active, start: at, end: at.addingTimeInterval(60)),
    ]
    #expect(utcExport.focusSessionsCSV(intervals) == utcExport.focusSessionsCSV(intervals.reversed()))
    let firstLine = utcExport.focusSessionsCSV(intervals).split(separator: "\r\n")[1]
    #expect(firstLine.hasPrefix("00000000-0000-0000-0000-00000000000A"))
  }

  @Test func timestampsCarryTheZoneOffset() {
    let instant = utcDate(2026, 1, 15, 17, 30, 15)
    #expect(utcExport.timestamp(instant) == "2026-01-15T17:30:15+00:00")
    #expect(newYorkExport.timestamp(instant) == "2026-01-15T12:30:15-05:00")
    let kolkata = InsightsExport(timeZone: TimeZone(identifier: "Asia/Kolkata")!)
    #expect(kolkata.timestamp(instant) == "2026-01-15T23:00:15+05:30")
    let summer = utcDate(2026, 7, 1, 12)
    #expect(newYorkExport.timestamp(summer) == "2026-07-01T08:00:00-04:00")
  }

  @Test func fractionalSecondsAreTruncatedNotRounded() {
    #expect(utcExport.timestamp(utcDate(2026, 11, 2, 12).addingTimeInterval(0.9)) == "2026-11-02T12:00:00+00:00")
  }

  @Test func fallBackDayKeepsBothRepeatedHoursDistinct() {
    let midnight = utcDate(2026, 11, 1, 4)
    let firstPass = midnight.addingTimeInterval(3600 + 1800)
    let secondPass = midnight.addingTimeInterval(2 * 3600 + 1800)
    let text = newYorkExport.breaksCSV([breakRecord(at: secondPass), breakRecord(at: firstPass)])
    let lines = text.split(separator: "\r\n").map(String.init)
    #expect(lines.count == 3)
    #expect(lines[1].hasPrefix("short,completed,2026-11-01T01:30:00-04:00,2026-11-01T01:30:20-04:00"))
    #expect(lines[2].hasPrefix("short,completed,2026-11-01T01:30:00-05:00,2026-11-01T01:30:20-05:00"))
  }

  @Test func springForwardDayNeverEmitsTheMissingHour() {
    let midnight = utcDate(2026, 3, 8, 5)
    let records = (0..<6).map { breakRecord(at: midnight.addingTimeInterval(Double($0) * 1800)) }
    let text = newYorkExport.breaksCSV(records)
    #expect(!text.contains("T02:"))
    #expect(text.contains("2026-03-08T01:30:00-05:00"))
    #expect(text.contains("2026-03-08T03:00:00-04:00"))
  }

  @Test func csvFieldQuotesPerRFC4180() {
    #expect(CSVEncoding.field("plain") == "plain")
    #expect(CSVEncoding.field("") == "")
    #expect(CSVEncoding.field("a,b") == "\"a,b\"")
    #expect(CSVEncoding.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
    #expect(CSVEncoding.field("line1\nline2") == "\"line1\nline2\"")
    #expect(CSVEncoding.field("line1\r\nline2") == "\"line1\r\nline2\"")
    #expect(CSVEncoding.field(" padded ") == " padded ")
    #expect(CSVEncoding.row(["a", "b,c", ""]) == "a,\"b,c\",\r\n")
  }

  @Test(arguments: ["=1+1", "+1", "-1", "@SUM(A1)", "=cmd|' /C calc'!A0"])
  func spreadsheetFormulasAreNeutralisedInsideQuotes(text: String) {
    let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
    #expect(CSVEncoding.field(text) == "\"'" + escaped + "\"")
  }

  @Test func onlyALeadingFormulaCharacterTriggersTheGuard() {
    #expect(CSVEncoding.field("a=1") == "a=1")
    #expect(CSVEncoding.field("1-2") == "1-2")
    #expect(CSVEncoding.field("x@y") == "x@y")
    #expect(CSVEncoding.field("=A,\"B\"") == "\"'=A,\"\"B\"\"\"")
  }

  @Test func signedNumbersAndTimestampsAreNotMangled() {
    let record = breakRecord(at: utcDate(2026, 11, 2, 12), seconds: 20, planned: 20)
    let line = utcExport.breaksCSV([record]).split(separator: "\r\n")[1]
    #expect(!line.contains("'"))
  }

  @Test func jsonMatchesExactBytes() {
    let records = [breakRecord(.short, .completed, at: utcDate(2026, 11, 2, 12))]
    let expected =
      "[{\"end\":\"2026-11-02T12:00:20+00:00\",\"kind\":\"short\",\"planned_seconds\":20,\"rested_seconds\":20,"
      + "\"result\":\"completed\",\"start\":\"2026-11-02T12:00:00+00:00\"}]"
    #expect(utcExport.breaksJSON(records) == expected)
    let wellness = [WellnessRecord(kind: .posture, at: utcDate(2026, 11, 2, 9), completed: true)]
    #expect(
      utcExport.wellnessJSON(wellness)
        == "[{\"at\":\"2026-11-02T09:00:00+00:00\",\"completed\":true,\"kind\":\"posture\"}]")
  }

  @Test func jsonRoundTripPreservesTheRecordCount() throws {
    let start = utcDate(2026, 11, 2, 9)
    let records = (0..<25).map { breakRecord(at: start.addingTimeInterval(Double($0) * 600)) }
    let data = Data(utcExport.breaksJSON(records).utf8)
    let decoded = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    #expect(decoded.count == 25)
    #expect(decoded.allSatisfy { $0["kind"] as? String == "short" })
    #expect(utcExport.breaksCSV(records).split(separator: "\r\n").count == 26)
  }

  @Test func focusSessionsJSONCarriesTheSessionID() throws {
    let start = utcDate(2026, 11, 2, 9)
    let interval = ActivityInterval(
      sessionID: sessionOne, kind: .active, start: start, end: start.addingTimeInterval(90))
    let data = Data(utcExport.focusSessionsJSON([interval]).utf8)
    let decoded = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    #expect(decoded.first?["session_id"] as? String == "00000000-0000-0000-0000-00000000000A")
    #expect(decoded.first?["duration_seconds"] as? Int == 90)
  }

  @Test func hostileDurationsStayFinite() {
    let record = BreakRecord(
      kind: .short, result: .completed, start: utcDate(2026, 11, 2, 12), end: utcDate(2026, 11, 2, 12),
      planned: .infinity)
    let line = utcExport.breaksCSV([record]).split(separator: "\r\n")[1]
    #expect(line.contains(",999999999,"))
    let nan = BreakRecord(
      kind: .short, result: .completed, start: utcDate(2026, 11, 2, 12), end: utcDate(2026, 11, 2, 12), planned: .nan)
    #expect(utcExport.breaksCSV([nan]).split(separator: "\r\n").count == 2)
  }

  @Test func renderRoutesEveryDatasetAndFormat() {
    let snapshot = TelemetrySnapshot(
      activity: [
        ActivityInterval(
          sessionID: sessionOne, kind: .active, start: utcDate(2026, 11, 2, 9), end: utcDate(2026, 11, 2, 10))
      ],
      breaks: [breakRecord(at: utcDate(2026, 11, 2, 12))],
      wellness: [WellnessRecord(kind: .blink, at: utcDate(2026, 11, 2, 11), completed: true)])
    #expect(utcExport.render(.breaks, format: .csv, from: snapshot) == utcExport.breaksCSV(snapshot.breaks))
    #expect(utcExport.render(.breaks, format: .json, from: snapshot) == utcExport.breaksJSON(snapshot.breaks))
    #expect(utcExport.render(.wellness, format: .csv, from: snapshot) == utcExport.wellnessCSV(snapshot.wellness))
    #expect(utcExport.render(.wellness, format: .json, from: snapshot) == utcExport.wellnessJSON(snapshot.wellness))
    #expect(
      utcExport.render(.focusSessions, format: .csv, from: snapshot) == utcExport.focusSessionsCSV(snapshot.activity))
    #expect(
      utcExport.render(.focusSessions, format: .json, from: snapshot) == utcExport.focusSessionsJSON(snapshot.activity))
  }

  @Test func fileNamesAreStable() {
    #expect(utcExport.fileName(for: .breaks, format: .csv) == "superzen-breaks.csv")
    #expect(utcExport.fileName(for: .wellness, format: .json) == "superzen-wellness.json")
    #expect(utcExport.fileName(for: .focusSessions, format: .csv) == "superzen-focus-sessions.csv")
  }
}
