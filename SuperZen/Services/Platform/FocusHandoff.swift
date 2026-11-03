import AppKit

@MainActor
protocol ApplicationActivating {
  var ownProcessID: pid_t { get }
  var isOwnAppActive: Bool { get }
  var isOwnWindowVisible: Bool { get }
  var lastExternalProcessID: pid_t? { get }
  func frontmostProcessID() -> pid_t?
  func activateOwnApp()
  func activate(processID: pid_t)
}

@MainActor
struct WorkspaceActivator: ApplicationActivating {
  var ownProcessID: pid_t { ProcessInfo.processInfo.processIdentifier }
  var isOwnAppActive: Bool { NSApp.isActive }
  var isOwnWindowVisible: Bool { MainWindow.find()?.isVisible == true }
  var lastExternalProcessID: pid_t? { FrontmostAppHistory.shared.lastExternalProcessID }

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
final class FrontmostAppHistory {
  static let shared = FrontmostAppHistory()

  private(set) var lastExternalProcessID: pid_t?
  private var observer: NSObjectProtocol?

  private init() {
    let ownProcessID = ProcessInfo.processInfo.processIdentifier
    if let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier, frontmost != ownProcessID {
      lastExternalProcessID = frontmost
    }
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] notification in
      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      let processID = app?.processIdentifier
      MainActor.assumeIsolated {
        guard let processID, processID != ownProcessID else { return }
        self?.lastExternalProcessID = processID
      }
    }
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
    if previous == nil, let frontmost = activator.frontmostProcessID() {
      if frontmost != activator.ownProcessID {
        previous = frontmost
      } else if !activator.isOwnWindowVisible {
        previous = activator.lastExternalProcessID
      }
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
