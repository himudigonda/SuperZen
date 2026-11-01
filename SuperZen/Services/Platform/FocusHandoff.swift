import AppKit

@MainActor
protocol ApplicationActivating {
  var ownProcessID: pid_t { get }
  var isOwnAppActive: Bool { get }
  func frontmostProcessID() -> pid_t?
  func activateOwnApp()
  func activate(processID: pid_t)
}

@MainActor
struct WorkspaceActivator: ApplicationActivating {
  var ownProcessID: pid_t { ProcessInfo.processInfo.processIdentifier }
  var isOwnAppActive: Bool { NSApp.isActive }

  func frontmostProcessID() -> pid_t? {
    NSWorkspace.shared.frontmostApplication?.processIdentifier
  }

  func activateOwnApp() {
    NSApp.activate(ignoringOtherApps: true)
  }

  func activate(processID: pid_t) {
    guard let app = NSRunningApplication(processIdentifier: processID), !app.isTerminated else { return }
    _ = app.activate(options: [])
  }
}

@MainActor
final class FocusHandoff {
  private let activator: any ApplicationActivating
  private var previous: pid_t?

  init(activator: (any ApplicationActivating)? = nil) {
    self.activator = activator ?? WorkspaceActivator()
  }

  func take() {
    if previous == nil, let frontmost = activator.frontmostProcessID(), frontmost != activator.ownProcessID {
      previous = frontmost
    }
    activator.activateOwnApp()
  }

  func giveBack() {
    guard let previous else { return }
    self.previous = nil
    guard activator.isOwnAppActive else { return }
    activator.activate(processID: previous)
  }
}
