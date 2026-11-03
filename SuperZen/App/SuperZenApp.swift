import AppKit
import SwiftData
import SwiftUI

@main
struct SuperZenApp: App {
  @StateObject private var stateManager = StateManager()

  private static let backgroundActivity: NSObjectProtocol = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiatedAllowingIdleSystemSleep],
    reason: "SuperZen Timer and Wellness Reminders"
  )

  init() {
    SettingKey.registerDefaults()
    ZenFontRegistry.register()
    _ = Self.backgroundActivity
    TelemetryService.shared.attach(Self.sharedModelContainer.mainContext)
  }

  static let sharedModelContainer = TelemetryStore.makeContainer()

  var body: some Scene {
    Window(MainWindow.title, id: MainWindow.id) {
      ContentView(stateManager: stateManager)
        .modelContainer(Self.sharedModelContainer)
        .background(WindowFrameAutosave())
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.automatic)
    .defaultPosition(.center)

    MenuBarExtra {
      MenuBarPopover(stateManager: stateManager)
    } label: {
      MenuBarLabel(stateManager: stateManager)
    }
    .menuBarExtraStyle(.window)
  }
}
