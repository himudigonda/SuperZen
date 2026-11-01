import AppKit
import Foundation
import Testing

@testable import SuperZen

@MainActor
@Suite(.serialized)
struct MainWindowTests {
  private func makeWindow() -> NSWindow {
    NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled, .resizable],
      backing: .buffered, defer: true)
  }

  @Test func windowKeepsItsFrameAcrossLaunches() {
    let name = "SuperZenTests.window.\(UUID().uuidString)"
    defer { NSWindow.removeFrame(usingName: name) }
    let first = makeWindow()
    #expect(MainWindow.persistFrame(of: first, named: name) == false)
    #expect(first.frameAutosaveName == name)
    let moved = NSRect(x: 120, y: 140, width: 520, height: 410)
    first.setFrame(moved, display: false)
    first.saveFrame(usingName: name)
    first.setFrameAutosaveName("")

    let second = makeWindow()
    #expect(MainWindow.persistFrame(of: second, named: name))
    #expect(second.frame.size == moved.size)
  }

  @Test func persistingTwiceIsANoOp() {
    let name = "SuperZenTests.window.\(UUID().uuidString)"
    defer { NSWindow.removeFrame(usingName: name) }
    let window = makeWindow()
    MainWindow.persistFrame(of: window, named: name)
    #expect(MainWindow.persistFrame(of: window, named: name) == false)
  }

  @Test func findsTheMainWindowByTitle() {
    let window = makeWindow()
    let other = makeWindow()
    window.title = MainWindow.title
    #expect(MainWindow.find(in: [other, window]) === window)
    #expect(MainWindow.find(in: [other]) == nil)
  }
}

@MainActor
@Suite struct OnboardingFlowTests {
  @Test func stepsTellTheTwentyRuleStoryInOrder() {
    #expect(OnboardingStep.allCases == [.welcome, .rule, .rhythm, .intensity, .finish])
    #expect(OnboardingStep.welcome.isFirst)
    #expect(OnboardingStep.finish.isLast)
    #expect(OnboardingStep.rule.next == .rhythm)
    #expect(OnboardingStep.rule.previous == .welcome)
    #expect(OnboardingStep.finish.next == nil)
    #expect(OnboardingStep.welcome.previous == nil)
  }

  @Test func ruleFactsFollowTheDefaults() {
    let facts = TwentyRuleFact.all(
      work: SettingsCatalog.workDurationDefault, rest: SettingsCatalog.breakDurationDefault)
    #expect(facts.map(\.value) == ["20", "20", "20"])
    #expect(Set(facts.map(\.id)).count == facts.count)
  }

  @Test func ruleFactsReflectCustomTimings() {
    let facts = TwentyRuleFact.all(work: 1500, rest: 30)
    #expect(facts.first?.value == "25")
    #expect(facts.last?.value == "30")
  }
}
