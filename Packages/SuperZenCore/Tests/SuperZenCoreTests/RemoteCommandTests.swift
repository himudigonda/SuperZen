import Foundation
import Testing

@testable import SuperZenCore

private func parse(_ text: String) -> RemoteCommand? {
  let fromString = RemoteCommand(string: text)
  if let url = URL(string: text) { #expect(RemoteCommand(url: url) == fromString) }
  return fromString
}

@Suite struct RemoteCommandTests {
  @Test func parsesEveryDocumentedCommand() {
    #expect(parse("superzen://start-break") == .startBreak)
    #expect(parse("superzen://skip") == .skip)
    #expect(parse("superzen://pause") == .pause(minutes: nil))
    #expect(parse("superzen://pause?minutes=15") == .pause(minutes: 15))
    #expect(parse("superzen://resume") == .resume)
    #expect(parse("superzen://postpone") == .postpone)
  }

  @Test func pauseMinutesAcceptTheWholeRangeAndNothingOutsideIt() {
    for minutes in RemoteCommand.pauseMinutesRange {
      #expect(parse("superzen://pause?minutes=\(minutes)") == .pause(minutes: minutes))
    }
    #expect(parse("superzen://pause?minutes=0") == nil)
    #expect(parse("superzen://pause?minutes=481") == nil)
    #expect(parse("superzen://pause?minutes=1000") == nil)
    #expect(parse("superzen://pause?minutes=99999999999999999999") == nil)
  }

  @Test(arguments: [
    "superzen://pause?minutes=-1",
    "superzen://pause?minutes=1e9",
    "superzen://pause?minutes=abc",
    "superzen://pause?minutes=",
    "superzen://pause?minutes=+5",
    "superzen://pause?minutes=05",
    "superzen://pause?minutes=5.0",
    "superzen://pause?minutes=%35",
    "superzen://pause?minutes=5%20",
    "superzen://pause?minutes=%EF%BC%95",
    "superzen://pause?minutes=5&minutes=6",
    "superzen://pause?minutes=5&extra=1",
    "superzen://pause?extra=1&minutes=5",
    "superzen://pause?minute=5",
    "superzen://pause?Minutes=5",
    "superzen://pause?minutes=5&",
    "superzen://pause?&minutes=5",
    "superzen://pause?",
    "superzen://pause?5",
    "superzen://pause?minutes=5#frag",
  ])
  func hostilePauseQueriesAreRejected(text: String) {
    #expect(parse(text) == nil)
  }

  @Test(arguments: [
    "superzen://pause/x",
    "superzen://pause/",
    "superzen://skip/",
    "superzen://skip/extra",
    "superzen://skip/../pause",
    "superzen://start-break/now",
    "superzen:///skip",
    "superzen://",
    "superzen:",
    "superzen:skip",
    "superzen://skip#fragment",
    "superzen://skip?now=1",
    "superzen://skip?",
    "superzen://resume?minutes=5",
    "superzen://start-break?minutes=5",
    "superzen://postpone?minutes=5",
    "superzen://user@skip",
    "superzen://skip:80",
    "superzen://skip@evil.example",
    "superzen://evil.example@skip",
    "superzen://skip.evil.example",
    "superzen://skip%00",
    "superzen://%73kip",
    "superzen://skip%20",
    " superzen://skip",
  ])
  func structuralAbuseIsRejected(text: String) {
    #expect(parse(text) == nil)
  }

  @Test(arguments: [
    "SUPERZEN://skip",
    "SuperZen://skip",
    "superzen://Skip",
    "superzen://SKIP",
    "superzen://Start-Break",
    "superzen://PAUSE?minutes=5",
    "superzen://Resume",
    "superzen://POSTPONE",
  ])
  func matchingIsCaseSensitive(text: String) {
    #expect(parse(text) == nil)
  }

  @Test(arguments: [
    "http://skip",
    "https://skip",
    "superzen2://skip",
    "xsuperzen://skip",
    "file:///skip",
    "javascript:skip",
    "superzen+x://skip",
  ])
  func otherSchemesAreRejected(text: String) {
    #expect(parse(text) == nil)
  }

  @Test(arguments: [
    "superzen://settings",
    "superzen://set?workDuration=1",
    "superzen://quit",
    "superzen://open",
    "superzen://start",
    "superzen://start_break",
    "superzen://unknown",
    "superzen://pause-forever",
    "superzen://pause,skip",
  ])
  func unknownHostsAreRejected(text: String) {
    #expect(parse(text) == nil)
  }

  @Test func stringInitialiserAppliesTheSameRules() {
    #expect(RemoteCommand(string: "superzen://skip") == .skip)
    #expect(RemoteCommand(string: "superzen://skip\n") == nil)
    #expect(RemoteCommand(string: "") == nil)
  }

  @Test func urlStringRoundTripsEveryValidCommand() {
    var commands: [RemoteCommand] = [.startBreak, .skip, .pause(minutes: nil), .resume, .postpone]
    commands += RemoteCommand.pauseMinutesRange.map { .pause(minutes: $0) }
    for command in commands {
      #expect(parse(command.urlString) == command)
    }
  }

  @Test func schemeConstantMatchesTheParsedPrefix() {
    #expect(RemoteCommand.scheme == "superzen")
    #expect(RemoteCommand.startBreak.urlString == "superzen://start-break")
    #expect(RemoteCommand.pause(minutes: 480).urlString == "superzen://pause?minutes=480")
  }
}
