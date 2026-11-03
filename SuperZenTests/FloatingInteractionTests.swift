import AppKit
import Combine
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
private final class InteractionModel: ObservableObject {
  @Published var selected = "none"
  @Published var isOn = false
  @Published var isDialogPresented = false
  @Published var confirmations = 0
  @Published var section = PreferencesSection.general
  @Published var isCollapsed = false
}

private final class TestWindow: NSWindow {
  override var canBecomeKey: Bool { true }
}

private struct ControlsRoot: View {
  @ObservedObject var model: InteractionModel
  var dismissesOnScrimTap = true

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      ZenMenu(items: [
        .action("A") { model.selected = "A" },
        .action("B") { model.selected = "B" },
      ]) {
        PickerPill(text: model.selected)
      }
      Toggle("Switch", isOn: $model.isOn).labelsHidden().toggleStyle(.zenSwitch)
      Button("Open") { model.isDialogPresented = true }.buttonStyle(.zenFilled)
    }
    .padding(40)
    .frame(width: 700, height: 460, alignment: .topLeading)
    .zenDialog(isPresented: $model.isDialogPresented, dismissesOnScrimTap: dismissesOnScrimTap) {
      Button("Confirm") {
        model.confirmations += 1
        model.isDialogPresented = false
      }
      .buttonStyle(.zenFilled)
    }
    .zenOverlayHost()
    .zenThemed()
  }
}

private struct ShellRoot: View {
  @ObservedObject var model: InteractionModel

  var body: some View {
    CustomSidebar(selection: $model.section, isCollapsed: $model.isCollapsed)
      .frame(width: CustomSidebar.drawerWidth, height: 650)
      .zenOverlayHost()
      .zenThemed()
  }
}

@MainActor
@Suite(.serialized)
struct FloatingInteractionTests {
  private static let menuTrigger = CGPoint(x: 60, y: 56)
  private static let menuFirstRowLeadingEdge = CGPoint(x: 52, y: 100)
  private static let switchCenter = CGPoint(x: 66, y: 112)
  private static let openButton = CGPoint(x: 80, y: 172)
  private static let windowCenter = CGPoint(x: 350, y: 230)
  private static let openButtonBelowMenu = CGPoint(x: 150, y: 186)

  private func settle(_ interval: TimeInterval = 0.4) {
    RunLoop.main.run(until: Date().addingTimeInterval(interval))
  }

  private func makeWindow<V: View>(_ view: V, size: CGSize) -> NSWindow {
    let window = TestWindow(
      contentRect: CGRect(origin: CGPoint(x: -6000, y: -6000), size: size), styleMask: [.titled], backing: .buffered,
      defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: view)
    window.setContentSize(size)
    window.setFrameOrigin(CGPoint(x: -6000, y: -6000))
    window.orderFront(nil)
    window.makeKey()
    settle()
    return window
  }

  private func click(_ window: NSWindow, at point: CGPoint) {
    let location = CGPoint(x: point.x, y: window.contentView!.bounds.height - point.y)
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

  private func press(_ window: NSWindow, keyCode: UInt16, characters: String) {
    for type in [NSEvent.EventType.keyDown, .keyUp] {
      window.sendEvent(
        NSEvent.keyEvent(
          with: type, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
          windowNumber: window.windowNumber, context: nil, characters: characters,
          charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)!)
    }
    settle()
  }

  @Test func switchTogglesOnClick() {
    let model = InteractionModel()
    let window = makeWindow(ControlsRoot(model: model), size: CGSize(width: 700, height: 460))
    defer { window.close() }
    click(window, at: Self.switchCenter)
    #expect(model.isOn)
  }

  @Test func menuRowAcceptsClicksAcrossItsFullWidth() {
    let model = InteractionModel()
    let window = makeWindow(ControlsRoot(model: model), size: CGSize(width: 700, height: 460))
    defer { window.close() }
    click(window, at: Self.menuTrigger)
    click(window, at: Self.menuFirstRowLeadingEdge)
    #expect(model.selected == "A")
  }

  @Test func menuSupportsKeyboardSelectionAndEscape() {
    let model = InteractionModel()
    let window = makeWindow(ControlsRoot(model: model), size: CGSize(width: 700, height: 460))
    defer { window.close() }
    click(window, at: Self.menuTrigger)
    press(window, keyCode: 125, characters: "\u{F701}")
    press(window, keyCode: 36, characters: "\r")
    #expect(model.selected == "A")
    click(window, at: Self.menuTrigger)
    press(window, keyCode: 53, characters: "\u{1b}")
    click(window, at: Self.switchCenter)
    #expect(model.isOn)
  }

  @Test func dialogActionsWorkAndEscapeDismisses() {
    let model = InteractionModel()
    let window = makeWindow(ControlsRoot(model: model), size: CGSize(width: 700, height: 460))
    defer { window.close() }
    click(window, at: Self.openButton)
    #expect(model.isDialogPresented)
    press(window, keyCode: 53, characters: "\u{1b}")
    #expect(!model.isDialogPresented)
    click(window, at: Self.openButton)
    click(window, at: Self.windowCenter)
    #expect(model.confirmations == 1)
    #expect(!model.isDialogPresented)
  }

  @Test func dialogScrimBlocksContentBehindIt() {
    let model = InteractionModel()
    let window = makeWindow(ControlsRoot(model: model), size: CGSize(width: 700, height: 460))
    defer { window.close() }
    click(window, at: Self.openButton)
    click(window, at: Self.switchCenter)
    #expect(!model.isOn)
    #expect(!model.isDialogPresented)
  }

  @Test func dialogThatKeepsEditsIgnoresScrimButStillEscapes() {
    let model = InteractionModel()
    let window = makeWindow(
      ControlsRoot(model: model, dismissesOnScrimTap: false), size: CGSize(width: 700, height: 460))
    defer { window.close() }
    click(window, at: Self.openButton)
    click(window, at: Self.switchCenter)
    #expect(model.isDialogPresented)
    #expect(!model.isOn)
    press(window, keyCode: 53, characters: "\u{1b}")
    #expect(!model.isDialogPresented)
  }

  @Test func clickOutsideClosesMenuWithoutTouchingWhatIsBelow() {
    let model = InteractionModel()
    let window = makeWindow(ControlsRoot(model: model), size: CGSize(width: 700, height: 460))
    defer { window.close() }
    click(window, at: Self.menuTrigger)
    click(window, at: Self.openButtonBelowMenu)
    #expect(model.selected == "none")
    #expect(!model.isDialogPresented)
    click(window, at: Self.switchCenter)
    #expect(model.isOn)
  }

  @Test func drawerSelectsSectionsAndCollapsesToRail() {
    let model = InteractionModel()
    let window = makeWindow(ShellRoot(model: model), size: CGSize(width: CustomSidebar.drawerWidth, height: 650))
    defer { window.close() }
    click(window, at: CGPoint(x: 100, y: 180))
    #expect(model.section == .breakSchedule)
    click(window, at: CGPoint(x: 236, y: 26))
    #expect(model.isCollapsed)
  }
}
