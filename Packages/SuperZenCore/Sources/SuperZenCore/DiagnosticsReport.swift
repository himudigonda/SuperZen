import Foundation

public struct DiagnosticsCounts: Equatable, Sendable {
  public var breaks: Int
  public var wellness: Int
  public var activity: Int

  public init(breaks: Int = 0, wellness: Int = 0, activity: Int = 0) {
    self.breaks = max(0, breaks)
    self.wellness = max(0, wellness)
    self.activity = max(0, activity)
  }
}

public enum DiagnosticsRedaction {
  public static let homeMarker = "~"

  private static let genericHomePattern = #"/(?:Users|home)/[^/\s"'\\:;,)]+"#

  public static func redact(_ text: String, homeDirectory: String = "") -> String {
    let specific = replacingHome(in: text, home: homeDirectory)
    guard let expression = try? NSRegularExpression(pattern: genericHomePattern) else { return specific }
    let range = NSRange(specific.startIndex..., in: specific)
    return expression.stringByReplacingMatches(
      in: specific, range: range, withTemplate: NSRegularExpression.escapedTemplate(for: homeMarker))
  }

  private static func replacingHome(in text: String, home: String) -> String {
    var base = home
    while base.count > 1 && base.hasSuffix("/") { base.removeLast() }
    guard base.count > 1 else { return text }
    var output = ""
    var cursor = text.startIndex
    while let match = text.range(of: base, range: cursor..<text.endIndex) {
      output += text[cursor..<match.lowerBound]
      if isBoundary(after: match.upperBound, in: text) {
        output += homeMarker
      } else {
        output += text[match]
      }
      cursor = match.upperBound
    }
    output += text[cursor...]
    return output
  }

  private static func isBoundary(after index: String.Index, in text: String) -> Bool {
    guard index < text.endIndex else { return true }
    let next = text[index]
    return !(next.isLetter || next.isNumber || next == "_" || next == "-" || next == ".")
  }
}

public struct DiagnosticsReport: Equatable, Sendable {
  public var version: String
  public var build: String
  public var osVersion: String
  public var localeIdentifier: String
  public var timeZoneIdentifier: String
  public var settings: Settings
  public var phaseLabel: String
  public var counts: DiagnosticsCounts
  public var homeDirectory: String

  public init(
    version: String,
    build: String,
    osVersion: String,
    localeIdentifier: String,
    timeZoneIdentifier: String,
    settings: Settings,
    phaseLabel: String,
    counts: DiagnosticsCounts = DiagnosticsCounts(),
    homeDirectory: String = ""
  ) {
    self.version = version
    self.build = build
    self.osVersion = osVersion
    self.localeIdentifier = localeIdentifier
    self.timeZoneIdentifier = timeZoneIdentifier
    self.settings = settings
    self.phaseLabel = phaseLabel
    self.counts = counts
    self.homeDirectory = homeDirectory
  }

  public var deferralAppCount: Int { settings.deferral.apps.count }

  public var settingsJSON: String {
    var sanitized = settings
    sanitized.deferral.apps = []
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(sanitized), let text = String(data: data, encoding: .utf8) else {
      return "unavailable"
    }
    return text
  }

  public var text: String {
    let lines = [
      "SuperZen Diagnostics",
      "Version: \(version)",
      "Build: \(build)",
      "macOS: \(osVersion)",
      "Locale: \(localeIdentifier)",
      "Time zone: \(timeZoneIdentifier)",
      "Phase: \(phaseLabel)",
      "Deferral apps: \(deferralAppCount)",
      "Break records: \(counts.breaks)",
      "Wellness records: \(counts.wellness)",
      "Activity records: \(counts.activity)",
      "Settings: \(settingsJSON)",
    ]
    return lines.map { Self.singleLine(DiagnosticsRedaction.redact($0, homeDirectory: homeDirectory)) }
      .joined(separator: "\n") + "\n"
  }

  private static func singleLine(_ text: String) -> String {
    text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
  }
}
