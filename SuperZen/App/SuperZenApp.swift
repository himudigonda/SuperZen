import AppKit
import SwiftData
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    NotificationCenter.default.post(name: MainWindow.reopenRequested, object: nil)
    return true
  }
}

@main
struct SuperZenApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  private let stateManager = StateManager.shared

  private static let backgroundActivity: NSObjectProtocol = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiatedAllowingIdleSystemSleep],
    reason: "SuperZen Timer and Wellness Reminders"
  )

  init() {
    SingleInstance.yieldToRunningInstance()
    _ = FrontmostAppHistory.shared
    SettingsMigrations.run(in: .standard)
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
    .commands {
      CommandGroup(replacing: .help) {}
    }

    MenuBarExtra {
      MenuBarPopover(stateManager: stateManager)
    } label: {
      MenuBarLabel(stateManager: stateManager)
    }
    .menuBarExtraStyle(.window)
  }
}
