import AppIntents
import Foundation
import SuperZenCore

struct StartBreakIntent: AppIntent {
  static let title: LocalizedStringResource = "Start Break"
  static let openAppWhenRun = false

  @MainActor func perform() async throws -> some IntentResult {
    CommandRouter.perform(.startBreak, on: StateManager.shared)
    return .result()
  }
}

struct PauseIntent: AppIntent {
  static let title: LocalizedStringResource = "Pause SuperZen"
  static let openAppWhenRun = false

  @Parameter(title: "Minutes", requestValueDialog: "How many minutes?")
  var minutes: Int?

  @MainActor func perform() async throws -> some IntentResult {
    CommandRouter.perform(.pause(minutes: minutes), on: StateManager.shared)
    return .result()
  }
}

struct ResumeIntent: AppIntent {
  static let title: LocalizedStringResource = "Resume SuperZen"
  static let openAppWhenRun = false

  @MainActor func perform() async throws -> some IntentResult {
    CommandRouter.perform(.resume, on: StateManager.shared)
    return .result()
  }
}

struct SkipBreakIntent: AppIntent {
  static let title: LocalizedStringResource = "Skip Current Break"
  static let openAppWhenRun = false

  @MainActor func perform() async throws -> some IntentResult {
    CommandRouter.perform(.skip, on: StateManager.shared)
    return .result()
  }
}

struct GetStatusIntent: AppIntent {
  static let title: LocalizedStringResource = "Get SuperZen Status"
  static let openAppWhenRun = false

  @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
    .result(value: CommandRouter.statusDescription(for: StateManager.shared))
  }
}

struct SuperZenShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartBreakIntent(), phrases: ["Start a break in \(.applicationName)"],
      shortTitle: "Start Break", systemImageName: "cup.and.saucer")
    AppShortcut(
      intent: PauseIntent(), phrases: ["Pause \(.applicationName)"],
      shortTitle: "Pause", systemImageName: "pause.circle")
    AppShortcut(
      intent: ResumeIntent(), phrases: ["Resume \(.applicationName)"],
      shortTitle: "Resume", systemImageName: "play.circle")
    AppShortcut(
      intent: SkipBreakIntent(), phrases: ["Skip break in \(.applicationName)"],
      shortTitle: "Skip Break", systemImageName: "forward.end")
    AppShortcut(
      intent: GetStatusIntent(), phrases: ["\(.applicationName) status"],
      shortTitle: "Status", systemImageName: "info.circle")
  }
}
