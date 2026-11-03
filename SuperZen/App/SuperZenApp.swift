import AppKit
import SwiftData
import SwiftUI

@main
struct SuperZenApp: App {
  @StateObject private var stateManager = StateManager(startsAutomatically: !AppRuntime.isHostingUnitTests)

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

  static let sharedModelContainer = TelemetryStore.makeAppContainer()

  private static var mainWindowLaunchBehavior: SceneLaunchBehavior {
    let opens = MainWindow.opensAtLaunch(
      hasCompletedOnboarding: UserDefaults.standard.bool(forKey: SettingKey.hasCompletedOnboarding),
      isHostingUnitTests: AppRuntime.isHostingUnitTests)
    return opens ? .presented : .suppressed
  }

  var body: some Scene {
    Window(MainWindow.title, id: MainWindow.id) {
      ContentView(stateManager: stateManager)
        .modelContainer(Self.sharedModelContainer)
        .background(WindowFrameAutosave())
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.automatic)
    .defaultPosition(.center)
    .defaultLaunchBehavior(Self.mainWindowLaunchBehavior)
    .restorationBehavior(.disabled)

    MenuBarExtra {
      MenuBarPopover(stateManager: stateManager)
    } label: {
      MenuBarLabel(stateManager: stateManager)
    }
    .menuBarExtraStyle(.window)
  }
}
