import AppKit
import Foundation
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
struct LayoutAndMotionTokenTests {
  @Test func spacingFollowsTheFourPointGrid() {
    #expect(ZenSpacing.scale.allSatisfy { $0.truncatingRemainder(dividingBy: 4) == 0 })
    #expect(ZenSpacing.scale == ZenSpacing.scale.sorted())
    #expect(Set(ZenSpacing.scale).count == ZenSpacing.scale.count)
  }

  @Test func radiusAndElevationScalesGrowMonotonically() {
    #expect(ZenRadius.scale == ZenRadius.scale.sorted())
    #expect(Set(ZenRadius.scale).count == ZenRadius.scale.count)
    let radii = ZenElevation.allCases.map(\.radius)
    let strengths = ZenElevation.allCases.map(\.shadowStrength)
    #expect(radii == radii.sorted())
    #expect(strengths == strengths.sorted())
    #expect(ZenElevation.level0.shadowStrength == 0)
  }

  @Test(arguments: ZenMotion.allCases)
  func reduceMotionDropsMovementAndKeepsShortCrossfades(_ motion: ZenMotion) {
    #expect(motion.animation(reduceMotion: false) != nil)
    let reduced = motion.animation(reduceMotion: true)
    if motion.movesContent {
      #expect(reduced == nil)
    } else {
      #expect(reduced != nil)
    }
  }

  @Test func motionDurationsStayResponsive() {
    #expect(ZenMotion.allCases.allSatisfy { $0.duration > 0 && $0.duration <= 1 })
    #expect(ZenMotion.quick.duration < ZenMotion.standard.duration)
  }

  @Test func stateLayerFollowsMaterialOpacities() {
    #expect(ZenStateLayer.opacity(isHovered: false, isPressed: false) == 0)
    #expect(ZenStateLayer.opacity(isHovered: true, isPressed: false) == 0.08)
    #expect(ZenStateLayer.opacity(isHovered: true, isPressed: true) == 0.10)
  }

  @Test func bundledFontsRegisterAndResolveByPostScriptName() {
    #expect(ZenFontRegistry.register())
    for face in ZenFontFace.allCases {
      #expect(NSFont(name: face.rawValue, size: 14) != nil, "\(face.rawValue)")
    }
  }

  @Test func statTileClampsProgress() {
    #expect(StatTile.clampedProgress(-0.5) == 0)
    #expect(StatTile.clampedProgress(0.4) == 0.4)
    #expect(StatTile.clampedProgress(3) == 1)
    #expect(StatTile.clampedProgress(.nan) == 0)
  }

  @Test(arguments: [
    (0.0, "0s"), (45.0, "45s"), (60.0, "1m"), (90.0, "1m 30s"), (3600.0, "1h"),
    (3900.0, "1h 5m"), (3605.0, "1h 5s"),
  ])
  func durationFormatIsCompact(_ seconds: Double, expected: String) {
    #expect(DurationFormat.compact(seconds) == expected)
  }

  @Test func durationParsingIgnoresJunkAndOverflow() {
    #expect(DurationFormat.seconds(hours: "1", minutes: "2a", seconds: " 3") == 3723)
    #expect(DurationFormat.seconds(hours: "", minutes: "", seconds: "") == 0)
    #expect(DurationFormat.seconds(hours: "99999999999", minutes: "0", seconds: "0") == 999_999 * 3600)
    #expect(DurationFormat.seconds(hours: "", minutes: "1.5", seconds: "") == 90)
    #expect(DurationFormat.seconds(hours: "", minutes: "0,5", seconds: "") == 30)
    #expect(DurationFormat.seconds(hours: "0.25", minutes: "", seconds: ".5") == 901)
  }
}
