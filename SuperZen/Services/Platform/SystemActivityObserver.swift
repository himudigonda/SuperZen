import AppKit
import SuperZenCore

@MainActor
final class SystemActivityObserver {
  private static let screenLocked = Notification.Name("com.apple.screenIsLocked")
  private static let screenUnlocked = Notification.Name("com.apple.screenIsUnlocked")

  private let onEvent: @MainActor (SessionEvent) -> Void
  private var tokens: [NSObjectProtocol] = []

  init(onEvent: @escaping @MainActor (SessionEvent) -> Void) {
    self.onEvent = onEvent
    let workspace = NSWorkspace.shared.notificationCenter
    tokens = [
      observe(workspace, NSWorkspace.willSleepNotification, .suspend(.sleep)),
      observe(workspace, NSWorkspace.didWakeNotification, .resume(.sleep)),
      observe(workspace, NSWorkspace.sessionDidResignActiveNotification, .suspend(.sessionSwitch)),
      observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification, .resume(.sessionSwitch)),
    ]
    let distributed = DistributedNotificationCenter.default()
    tokens += [
      observe(distributed, Self.screenLocked, .suspend(.screenLock)),
      observe(distributed, Self.screenUnlocked, .resume(.screenLock)),
    ]
  }

  private func observe(
    _ center: NotificationCenter, _ name: Notification.Name, _ event: SessionEvent
  ) -> NSObjectProtocol {
    center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.onEvent(event) }
    }
  }
}
