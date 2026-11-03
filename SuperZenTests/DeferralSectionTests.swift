import AppKit
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct DeferralSectionTests {
  private final class TestWindow: NSWindow {
    override var canBecomeKey: Bool { true }
  }

  private let suiteName = "com.himudigonda.SuperZenTests.deferral-section.\(UUID().uuidString)"
  private let defaults: UserDefaults

  init() {
    defaults = UserDefaults(suiteName: suiteName)!
  }

  private func settle(_ interval: TimeInterval = 0.4) {
    RunLoop.main.run(until: Date().addingTimeInterval(interval))
  }

  private func show(_ defaults: UserDefaults) -> NSWindow {
    let size = CGSize(width: 760, height: 720)
    let window = TestWindow(
      contentRect: CGRect(origin: CGPoint(x: -6000, y: -6000), size: size), styleMask: [.titled], backing: .buffered,
      defer: false)
    window.isReleasedWhenClosed = false
    let root = DeferralSection(defaults: defaults)
      .padding(ZenSpacing.lg)
      .frame(width: size.width, height: size.height, alignment: .top)
      .zenOverlayHost()
      .zenThemed()
    window.contentView = NSHostingView(rootView: root)
    window.setContentSize(size)
    window.setFrameOrigin(CGPoint(x: -6000, y: -6000))
    window.orderFront(nil)
    window.makeKey()
    settle(0.6)
    return window
  }

  private func click(_ window: NSWindow, x: CGFloat, y: CGFloat) {
    let location = CGPoint(x: x, y: window.contentView!.bounds.height - y)
    for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
      window.sendEvent(
        NSEvent.mouseEvent(
          with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
          windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
          pressure: type == .leftMouseDown ? 1 : 0)!)
      settle(0.06)
    }
    settle()
  }

  private func renderedHeight(apps: String) -> CGFloat {
    defaults.set(apps, forKey: SettingKey.deferralApps)
    let host = NSHostingView(rootView: DeferralSection(defaults: defaults).frame(width: 700).zenThemed())
    return host.fittingSize.height
  }

  @Test func sectionGrowsByOneRowPerListedApp() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let none = renderedHeight(apps: "")
    let two = renderedHeight(apps: "com.apple.finder,not.an.installed.app")
    #expect(none > 250)
    #expect(two - none > 2 * 56)
    #expect(two - none < 2 * 80)
  }

  @Test func theCallSwitchWritesItsKey() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let window = show(defaults)
    defer { window.close() }
    click(window, x: 698, y: 82)
    #expect(defaults.object(forKey: SettingKey.deferralDuringCalls) as? Bool == false)
  }

  @Test func theFullscreenSwitchWritesItsKey() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let window = show(defaults)
    defer { window.close() }
    click(window, x: 698, y: 148)
    #expect(defaults.object(forKey: SettingKey.deferralDuringFullscreen) as? Bool == true)
  }

  @Test func removeButtonDropsOnlyThatApp() {
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("com.apple.finder,not.an.installed.app", forKey: SettingKey.deferralApps)
    let window = show(defaults)
    defer { window.close() }
    click(window, x: 708, y: 322)
    #expect(defaults.string(forKey: SettingKey.deferralApps) == "com.apple.finder")
  }

  @Test func appListEditsKeepTheCSVClean() {
    #expect(DeferralAppList.csv(adding: "a.b", to: "") == "a.b")
    #expect(DeferralAppList.csv(adding: "a.b", to: "a.b") == "a.b")
    #expect(DeferralAppList.csv(adding: "c.d", to: " a.b , ,") == "a.b,c.d")
    #expect(DeferralAppList.csv(removing: "a.b", from: "a.b,c.d") == "c.d")
    #expect(DeferralAppList.csv(removing: "x.y", from: "a.b") == "a.b")
  }

  @Test func unreadableBundleYieldsNoIdentifier() {
    #expect(DeferralAppList.bundleID(ofAppAt: URL(fileURLWithPath: "/nonexistent/Missing.app")) == nil)
    #expect(
      DeferralAppList.bundleID(ofAppAt: URL(fileURLWithPath: "/System/Applications/Calculator.app"))
        == "com.apple.calculator")
  }

  @Test func missingBundleFallsBackToTheIdentifier() {
    let descriptor = DeferralAppDescriptor(bundleID: "not.an.installed.app")
    #expect(descriptor.name == "not.an.installed.app")
    #expect(descriptor.icon == nil)
  }

  @Test func capOptionsMatchTheSpecAndContainTheDefault() {
    #expect(DeferralAppList.capOptions.map(\.1) == [300, 600, 900, 1800])
    #expect(DeferralAppList.capOptions.map(\.1).contains(DeferralSettings().cap))
  }
}
