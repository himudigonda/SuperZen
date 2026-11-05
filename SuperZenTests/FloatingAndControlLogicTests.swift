import AppKit
import Foundation
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
struct FloatingAndControlLogicTests {
  private func items(_ selected: String? = nil, disabled: Set<String> = []) -> [ZenMenuItem] {
    ["a", "b", "c"].map { id in
      .action(id: id, id, isSelected: id == selected, isEnabled: !disabled.contains(id)) {}
    } + [.divider(id: "d")]
  }

  @Test func menuNavigationWrapsAndSkipsDisabledAndDividers() {
    let list = items(disabled: ["b"])
    #expect(ZenMenuNavigation.next(from: nil, in: list, forward: true) == "a")
    #expect(ZenMenuNavigation.next(from: nil, in: list, forward: false) == "c")
    #expect(ZenMenuNavigation.next(from: "a", in: list, forward: true) == "c")
    #expect(ZenMenuNavigation.next(from: "c", in: list, forward: true) == "a")
    #expect(ZenMenuNavigation.next(from: "a", in: list, forward: false) == "c")
  }

  @Test func menuOpensOnTheSelectedRow() {
    #expect(ZenMenuNavigation.initial(in: items("b")) == "b")
    #expect(ZenMenuNavigation.initial(in: items()) == nil)
    #expect(ZenMenuNavigation.initial(in: items("b", disabled: ["b"])) == nil)
    #expect(ZenMenuNavigation.next(from: nil, in: [.divider(id: "d")], forward: true) == nil)
  }

  private let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)

  @Test func menuOpensBelowAndAlignsToTheAnchor() {
    let origin = ZenAnchorGeometry.origin(
      size: CGSize(width: 200, height: 100), anchor: CGRect(x: 100, y: 100, width: 80, height: 32), bounds: bounds,
      placement: .menu, gap: 4)
    #expect(origin == CGPoint(x: 100, y: 136))
  }

  @Test func menuFlipsAboveAndTrailingAlignsNearTheEdges() {
    let origin = ZenAnchorGeometry.origin(
      size: CGSize(width: 200, height: 100), anchor: CGRect(x: 700, y: 540, width: 80, height: 32), bounds: bounds,
      placement: .menu, gap: 4)
    #expect(origin == CGPoint(x: 580, y: 436))
  }

  @Test func oversizedMenuStaysInsideTheWindow() {
    let origin = ZenAnchorGeometry.origin(
      size: CGSize(width: 200, height: 584), anchor: CGRect(x: 100, y: 300, width: 80, height: 32), bounds: bounds,
      placement: .menu, gap: 4)
    #expect(origin.y == 8)
    #expect(origin.y + 584 <= bounds.maxY - 8)
  }

  @Test func tooltipCentresAndClampsToTheWindow() {
    let centred = ZenAnchorGeometry.origin(
      size: CGSize(width: 100, height: 24), anchor: CGRect(x: 300, y: 100, width: 40, height: 40), bounds: bounds,
      placement: .tooltip, gap: 4)
    #expect(centred.x == 270)
    let clamped = ZenAnchorGeometry.origin(
      size: CGSize(width: 100, height: 24), anchor: CGRect(x: 0, y: 100, width: 40, height: 40), bounds: bounds,
      placement: .tooltip, gap: 4)
    #expect(clamped.x == 8)
  }

  @Test func sliderSnapsToStepsAndClamps() {
    #expect(ZenSliderMath.value(fraction: 0.26, in: 0...1, step: 0.25) == 0.25)
    #expect(ZenSliderMath.value(fraction: 2, in: 0...1, step: 0.1) == 1)
    #expect(ZenSliderMath.value(fraction: -1, in: 0...1, step: nil) == 0)
    #expect(ZenSliderMath.value(fraction: .nan, in: 10...20, step: nil) == 10)
    #expect(ZenSliderMath.fraction(value: 15, in: 10...20) == 0.5)
    #expect(ZenSliderMath.fraction(value: 5, in: 5...5) == 0)
  }

  @Test func linearProgressClampsBadValues() {
    #expect(ZenLinearProgress(value: 2).clampedValue == 1)
    #expect(ZenLinearProgress(value: -1).clampedValue == 0)
    #expect(ZenLinearProgress(value: .nan).clampedValue == 0)
  }
}
