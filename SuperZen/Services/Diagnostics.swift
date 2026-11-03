import AppKit
import Foundation
import SuperZenCore
import SwiftData

enum Diagnostics {
  static func counts(in context: ModelContext?) -> DiagnosticsCounts {
    guard let context else { return DiagnosticsCounts() }
    return DiagnosticsCounts(
      breaks: (try? context.fetchCount(FetchDescriptor<BreakRecordModel>())) ?? 0,
      wellness: (try? context.fetchCount(FetchDescriptor<WellnessRecordModel>())) ?? 0,
      activity: (try? context.fetchCount(FetchDescriptor<ActivityRecordModel>())) ?? 0)
  }

  static func report(
    phaseLabel: String,
    context: ModelContext?,
    defaults: UserDefaults = .standard,
    bundle: Bundle = .main,
    homeDirectory: String = NSHomeDirectory()
  ) -> DiagnosticsReport {
    let info = bundle.infoDictionary
    return DiagnosticsReport(
      version: info?["CFBundleShortVersionString"] as? String ?? "unknown",
      build: info?["CFBundleVersion"] as? String ?? "unknown",
      osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
      localeIdentifier: Locale.current.identifier,
      timeZoneIdentifier: TimeZone.current.identifier,
      settings: LegacySettingsMigration.migrate { defaults.object(forKey: $0) },
      phaseLabel: phaseLabel,
      counts: counts(in: context),
      homeDirectory: homeDirectory)
  }

  @MainActor
  static func copyToPasteboard(phaseLabel: String) {
    let text = report(phaseLabel: phaseLabel, context: TelemetryService.shared.context).text
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }
}
