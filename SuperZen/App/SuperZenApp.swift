import SwiftData
import SwiftUI

@main
struct SuperZenApp: App {
  // Inject the StateManager as a Global Object
  @StateObject private var stateManager = StateManager()

  var body: some Scene {
    // Standard WindowGroup is hidden by Info.plist settings,
    // but we keep it for the Settings/Dashboard views later.
    WindowGroup {
      ContentView()
        .environmentObject(stateManager)
    }

    // This creates the actual Menu Bar Icon
    MenuBarExtra {
      VStack {
        Text("SuperZen: \(stateManager.status.description)")

        Divider()

        Button("Start Break Now") {
          stateManager.transition(to: .onBreak)
        }

        Button(stateManager.status == .paused ? "Resume" : "Pause") {
          stateManager.togglePause()
        }

        Divider()

        Button("Settings...") {
          // Open the main window
          NSApp.activate(ignoringOtherApps: true)
          if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
          }
        }

        Button("Quit SuperZen") {
          NSApplication.shared.terminate(nil)
        }
      }
    } label: {
      HStack {
        Image(systemName: "eye.circle.fill")
        if stateManager.status == .nudge {
          Text("\(Int(stateManager.nudgeTimeRemaining))s")
        }
      }
    }
  }
}
