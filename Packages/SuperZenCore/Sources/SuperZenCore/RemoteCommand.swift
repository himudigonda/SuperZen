import Foundation

public enum RemoteCommand: Equatable, Sendable {
  case startBreak
  case skip
  case pause(minutes: Int?)
  case resume
  case postpone

  public static let scheme = "superzen"
  public static let pauseMinutesRange = 1...480

  private static let prefix = scheme + "://"
  private static let minutesParameter = "minutes="

  public init?(url: URL) {
    guard let command = Self.parse(url.absoluteString) else { return nil }
    self = command
  }

  public init?(string: String) {
    guard let command = Self.parse(string) else { return nil }
    self = command
  }

  public var urlString: String {
    switch self {
    case .startBreak: return Self.prefix + "start-break"
    case .skip: return Self.prefix + "skip"
    case .pause(let minutes):
      guard let minutes else { return Self.prefix + "pause" }
      return Self.prefix + "pause?" + Self.minutesParameter + String(minutes)
    case .resume: return Self.prefix + "resume"
    case .postpone: return Self.prefix + "postpone"
    }
  }

  private static func parse(_ text: String) -> RemoteCommand? {
    guard text.hasPrefix(prefix) else { return nil }
    let rest = text.dropFirst(prefix.count)
    let parts = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
    guard let host = parts.first else { return nil }
    let query: Substring? = parts.count > 1 ? parts[1] : nil
    switch host {
    case "pause": return parsePause(query: query)
    case "start-break": return query == nil ? .startBreak : nil
    case "skip": return query == nil ? .skip : nil
    case "resume": return query == nil ? .resume : nil
    case "postpone": return query == nil ? .postpone : nil
    default: return nil
    }
  }

  private static func parsePause(query: Substring?) -> RemoteCommand? {
    guard let query else { return .pause(minutes: nil) }
    guard query.hasPrefix(minutesParameter) else { return nil }
    let digits = query.dropFirst(minutesParameter.count)
    guard
      (1...3).contains(digits.utf8.count),
      digits.utf8.allSatisfy({ (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) }),
      digits.first != "0",
      let minutes = Int(digits),
      pauseMinutesRange.contains(minutes)
    else { return nil }
    return .pause(minutes: minutes)
  }
}
