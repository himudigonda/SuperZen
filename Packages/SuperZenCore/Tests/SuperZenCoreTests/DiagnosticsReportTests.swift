import Foundation
import Testing

@testable import SuperZenCore

private func report(
  settings: Settings = Settings(),
  phase: String = "focus",
  home: String = "/Users/alice"
) -> DiagnosticsReport {
  DiagnosticsReport(
    version: "2.0.0", build: "200", osVersion: "Version 15.1 (Build 24B83)", localeIdentifier: "en_US",
    timeZoneIdentifier: "America/Phoenix", settings: settings, phaseLabel: phase,
    counts: DiagnosticsCounts(breaks: 12, wellness: 34, activity: 56), homeDirectory: home)
}

@Suite struct DiagnosticsReportTests {
  @Test func linesAppearInAStableOrder() {
    let lines = report().text.split(separator: "\n").map(String.init)
    let labels = lines.map { $0.prefix(while: { $0 != ":" }) }
    #expect(
      labels.map(String.init) == [
        "SuperZen Diagnostics", "Version", "Build", "macOS", "Locale", "Time zone", "Phase", "Deferral apps",
        "Break records", "Wellness records", "Activity records", "Settings",
      ])
    #expect(lines[1] == "Version: 2.0.0")
    #expect(lines[2] == "Build: 200")
    #expect(lines[3] == "macOS: Version 15.1 (Build 24B83)")
    #expect(lines[4] == "Locale: en_US")
    #expect(lines[5] == "Time zone: America/Phoenix")
    #expect(lines[6] == "Phase: focus")
    #expect(lines[8] == "Break records: 12")
    #expect(lines[9] == "Wellness records: 34")
    #expect(lines[10] == "Activity records: 56")
  }

  @Test func outputIsDeterministic() {
    #expect(report().text == report().text)
    var shuffled = Settings()
    shuffled.deferral.apps = ["b.app", "a.app"]
    var other = Settings()
    other.deferral.apps = ["a.app", "b.app"]
    #expect(
      report(settings: shuffled).text.split(separator: "\n").dropLast()
        == report(settings: other).text.split(separator: "\n").dropLast())
  }

  @Test func endsWithASingleNewline() {
    let text = report().text
    #expect(text.hasSuffix("}\n"))
    #expect(!text.hasSuffix("\n\n"))
  }

  @Test func trackedAppNamesNeverAppearOnlyTheirCount() {
    var settings = Settings()
    settings.deferral.apps = ["us.zoom.xos", "com.secret.Vault", "com.apple.FaceTime"]
    let value = report(settings: settings)
    #expect(value.text.contains("Deferral apps: 3"))
    for name in settings.deferral.apps {
      #expect(!value.text.contains(name))
    }
    #expect(!value.settingsJSON.contains("us.zoom.xos"))
  }

  @Test func settingsAreEncodedWithTheTimerValues() {
    var settings = Settings()
    settings.timer.workDuration = 1500
    let json = report(settings: settings).settingsJSON
    #expect(json.contains("\"workDuration\":1500"))
    #expect(json.hasPrefix("{"))
    let data = Data(json.utf8)
    #expect((try? JSONSerialization.jsonObject(with: data)) != nil)
  }

  @Test func homePathsAreRedactedFromEveryField() {
    let value = DiagnosticsReport(
      version: "/Users/alice/Library/v", build: "/Users/alice", osVersion: "see /Users/alice/Documents/x",
      localeIdentifier: "/Users/alice/loc", timeZoneIdentifier: "/Users/alice/tz",
      settings: Settings(), phaseLabel: "paused /Users/alice/Desktop", homeDirectory: "/Users/alice")
    #expect(!value.text.contains("alice"))
    #expect(!value.text.contains("/Users"))
    #expect(value.text.contains("Build: ~\n"))
  }

  @Test func unknownHomeDirectoriesAreStillRedactedByShape() {
    let value = report(phase: "reading /Users/bob/Notes and /home/carol/.config", home: "/Users/alice")
    #expect(!value.text.contains("bob"))
    #expect(!value.text.contains("carol"))
    #expect(value.text.contains("reading ~/Notes and ~/.config"))
  }

  @Test func plannedBreakIdsCannotLeakAHomePath() {
    var settings = Settings()
    settings.plannedBreaks = [PlannedBreak(id: "/Users/dave/lunch", minuteOfDay: 750, weekdays: [2], duration: 900)]
    let value = report(settings: settings)
    #expect(!value.text.contains("dave"))
  }

  @Test func freeTextCannotInjectExtraLines() {
    let value = report(phase: "focus\nBuild: forged\r\nSettings: {}")
    let lines = value.text.split(separator: "\n").map(String.init)
    #expect(lines.count == 12)
    #expect(lines.filter { $0.hasPrefix("Build:") }.count == 1)
  }

  @Test func redactionReplacesTheHomePrefixAtPathBoundaries() {
    let home = "/Users/alice"
    #expect(DiagnosticsRedaction.redact("/Users/alice", homeDirectory: home) == "~")
    #expect(DiagnosticsRedaction.redact("/Users/alice/", homeDirectory: home) == "~/")
    #expect(DiagnosticsRedaction.redact("/Users/alice/Desktop/a.png", homeDirectory: home) == "~/Desktop/a.png")
    #expect(DiagnosticsRedaction.redact("a=/Users/alice/x b=/Users/alice/y", homeDirectory: home) == "a=~/x b=~/y")
    #expect(DiagnosticsRedaction.redact("no paths here", homeDirectory: home) == "no paths here")
    #expect(DiagnosticsRedaction.redact("", homeDirectory: home) == "")
  }

  @Test func redactionDoesNotEatLongerNamesSharingThePrefix() {
    let result = DiagnosticsRedaction.redact("/Users/alice2/x", homeDirectory: "/Users/alice")
    #expect(result == "~/x")
    let custom = DiagnosticsRedaction.redact("/data/alicex/y /data/alice/z", homeDirectory: "/data/alice")
    #expect(custom == "/data/alicex/y ~/z")
  }

  @Test func redactionToleratesTrailingSlashAndRootHomes() {
    #expect(DiagnosticsRedaction.redact("/Users/alice/x", homeDirectory: "/Users/alice/") == "~/x")
    #expect(DiagnosticsRedaction.redact("/etc/hosts", homeDirectory: "/") == "/etc/hosts")
    #expect(DiagnosticsRedaction.redact("/etc/hosts", homeDirectory: "") == "/etc/hosts")
  }

  @Test func countsAreFlooredAtZero() {
    let counts = DiagnosticsCounts(breaks: -1, wellness: -2, activity: -3)
    #expect(counts == DiagnosticsCounts())
  }
}
