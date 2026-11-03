import AppKit
import Foundation
import SuperZenCore
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
struct ColorTokenTests {
  private let schemes: [ColorScheme] = [.light, .dark]

  @Test(arguments: [
    ("0A84FF", ZenRGBA(rgb: 0x0A84FF)),
    ("#0a84ff", ZenRGBA(rgb: 0x0A84FF)),
    ("FFF", ZenRGBA(red: 1, green: 1, blue: 1)),
    ("FF000080", ZenRGBA(rgb: 0xFF0000, alpha: 128.0 / 255)),
  ])
  func hexParsesValidInput(_ input: String, expected: ZenRGBA) {
    #expect(ZenRGBA(hex: input) == expected)
  }

  @Test(arguments: ["", "#", "12", "GGGGGG", "12345", "+12345", "0A84FF00FF"])
  func hexRejectsInvalidInputInsteadOfFallingBack(_ input: String) {
    #expect(ZenRGBA(hex: input) == nil)
  }

  @Test func contrastRatioMatchesWCAGReferencePoints() {
    #expect(abs(ZenRGBA.black.contrastRatio(against: .white) - 21) < 0.01)
    #expect(abs(ZenRGBA.white.contrastRatio(against: .white) - 1) < 0.0001)
  }

  private static let surfaces: [ZenColorRole] = [
    .surface, .surfaceDim, .surfaceBright, .surfaceContainerLowest, .surfaceContainerLow, .surfaceContainer,
    .surfaceContainerHigh, .surfaceContainerHighest,
  ]

  private static let pairs: [(ZenColorRole, ZenColorRole)] = [
    (.onPrimary, .primary), (.onPrimaryContainer, .primaryContainer), (.onSecondary, .secondary),
    (.onSecondaryContainer, .secondaryContainer), (.onTertiary, .tertiary),
    (.onTertiaryContainer, .tertiaryContainer), (.onError, .error), (.onErrorContainer, .errorContainer),
    (.onSuccess, .success), (.onSuccessContainer, .successContainer), (.onWarning, .warning),
    (.onWarningContainer, .warningContainer), (.onInfo, .info), (.onInfoContainer, .infoContainer),
    (.inverseOnSurface, .inverseSurface),
  ]

  @Test(arguments: ContrastProfile.allCases)
  func bodyTextMeetsWCAGAAOnEverySurfaceInBothSchemes(_ profile: ContrastProfile) {
    for palette in AccentPalette.allCases {
      let theme = ZenTheme(accent: palette, contrast: profile)
      for scheme in schemes {
        for role in Self.surfaces {
          let surface = theme.rgba(role, scheme: scheme)
          #expect(theme.rgba(.onSurface, scheme: scheme).contrastRatio(against: surface) >= 7)
          #expect(theme.rgba(.onSurfaceVariant, scheme: scheme).contrastRatio(against: surface) >= 4.5)
        }
      }
    }
  }

  @Test(arguments: ContrastProfile.allCases)
  func everyOnRoleMeetsWCAGAAOnItsContainer(_ profile: ContrastProfile) {
    for palette in AccentPalette.allCases {
      let theme = ZenTheme(accent: palette, contrast: profile)
      for scheme in schemes {
        for (on, container) in Self.pairs {
          let ratio = theme.rgba(on, scheme: scheme).contrastRatio(against: theme.rgba(container, scheme: scheme))
          #expect(ratio >= 4.5, "\(on) on \(container), \(palette) \(profile) \(scheme): \(ratio)")
        }
      }
    }
  }

  @Test(arguments: AccentPalette.allCases)
  func primaryMeetsNonTextContrastInBothSchemes(_ palette: AccentPalette) {
    let theme = ZenTheme(accent: palette, contrast: .balanced)
    for scheme in schemes {
      let canvas = theme.rgba(.surface, scheme: scheme)
      #expect(theme.rgba(.primary, scheme: scheme).contrastRatio(against: canvas) >= 3)
    }
  }

  @Test(arguments: [ZenColorRole.success, .warning, .error, .info])
  func statusColorsMeetNonTextContrastInBothSchemes(_ role: ZenColorRole) {
    for scheme in schemes {
      let canvas = ZenTheme.standard.rgba(.surface, scheme: scheme)
      #expect(ZenTheme.standard.rgba(role, scheme: scheme).contrastRatio(against: canvas) >= 3)
    }
  }

  @Test func lightAndDarkResolveDifferentlyForAdaptiveRoles() {
    for role in [ZenColorRole.surface, .onSurface, .onSurfaceVariant, .surfaceContainer, .primary] {
      #expect(ZenTheme.standard.rgba(role, scheme: .light) != ZenTheme.standard.rgba(role, scheme: .dark))
    }
  }

  @Test func overlayRolesIgnoreTheColorScheme() {
    for role in [ZenColorRole.overlayText, .overlaySurface, .overlayStroke, .overlayScrim] {
      #expect(ZenTheme.standard.rgba(role, scheme: .light) == ZenTheme.standard.rgba(role, scheme: .dark))
    }
  }

  @Test func contrastProfilesOrderOutlineAndTextStrength() {
    for scheme in schemes {
      func ratios(_ role: ZenColorRole) -> [Double] {
        ContrastProfile.allCases.map {
          let theme = ZenTheme(accent: .ocean, contrast: $0)
          return theme.rgba(role, scheme: scheme).contrastRatio(against: theme.rgba(.surface, scheme: scheme))
        }
      }
      for role in [ZenColorRole.outlineVariant, .outline] {
        let values = ratios(role)
        #expect(values == values.sorted())
        #expect(Set(values).count == values.count)
      }
      let text = ratios(.onSurfaceVariant)
      #expect(text[2] > text[1])
    }
  }

  @Test func surfaceContainersStepMonotonicallyFromTheCanvas() {
    let order: [ZenColorRole] = [
      .surfaceContainerLow, .surfaceContainer, .surfaceContainerHigh, .surfaceContainerHighest,
    ]
    let light = order.map { ZenTheme.standard.rgba($0, scheme: .light).relativeLuminance }
    let dark = order.map { ZenTheme.standard.rgba($0, scheme: .dark).relativeLuminance }
    #expect(light == light.sorted(by: >))
    #expect(dark == dark.sorted())
  }

  @Test(arguments: [0.0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 98, 100])
  func tonalPaletteHitsTheRequestedLuminance(_ tone: Double) {
    for palette in AccentPalette.allCases.map(\.palettes.primary) + [ZenCorePalettes.error, ZenCorePalettes.warning] {
      let luminance = palette.tone(tone).relativeLuminance
      #expect(abs(luminance - ZenTonalPalette.luminance(forTone: tone)) < 0.004)
    }
  }

  @Test func toneDistanceGuaranteesContrast() {
    let palette = AccentPalette.sunset.palettes.primary
    #expect(palette.tone(40).contrastRatio(against: palette.tone(90)) >= 4.5)
    #expect(palette.tone(50).contrastRatio(against: palette.tone(90)) >= 3)
  }

  @Test func seedConversionRoundTripsThroughOKLCH() {
    let seed = ZenRGBA(rgb: 0x007AFF)
    let result = ZenOKLCH(seed).clampedToGamut
    #expect(abs(result.red - seed.red) < 0.01)
    #expect(abs(result.green - seed.green) < 0.01)
    #expect(abs(result.blue - seed.blue) < 0.01)
  }

  @Test func systemIncreasedContrastEscalatesToHigh() {
    for profile in ContrastProfile.allCases {
      #expect(profile.escalated(systemIncreasedContrast: true) == .high)
      #expect(profile.escalated(systemIncreasedContrast: false) == profile)
    }
  }

  @Test func accentPaletteRetintsWithoutChangingStatusOrOverlayRoles() {
    let ocean = ZenTheme(accent: .ocean, contrast: .balanced)
    let sunset = ZenTheme(accent: .sunset, contrast: .balanced)
    #expect(ocean.rgba(.primary, scheme: .light) != sunset.rgba(.primary, scheme: .light))
    for role in [ZenColorRole.error, .success, .warning, .info, .overlayText, .overlaySurface] {
      #expect(ocean.rgba(role, scheme: .light) == sunset.rgba(role, scheme: .light))
    }
  }

  @Test func storedSettingsTokensMapToEveryEnumCase() {
    #expect(SettingsCatalog.accentPalettes.compactMap(AccentPalette.init(rawValue:)) == AccentPalette.allCases)
    #expect(
      SettingsCatalog.contrastProfiles.compactMap(ContrastProfile.init(rawValue:))
        == ContrastProfile.allCases)
    #expect(AccentPalette(storedValue: SettingsCatalog.accentPaletteDefault) == .ocean)
    #expect(ContrastProfile(storedValue: SettingsCatalog.contrastProfileDefault) == .balanced)
    #expect(AccentPalette(storedValue: "Neon") == .ocean)
    #expect(ContrastProfile(storedValue: nil) == .balanced)
  }
}

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

@MainActor
struct SchedulePickerLogicTests {
  @Test func timeFormatFollowsTheLocale() {
    let us = ZenTimeFormat.string(minuteOfDay: 9 * 60, locale: Locale(identifier: "en_US"))
    let british = ZenTimeFormat.string(minuteOfDay: 9 * 60, locale: Locale(identifier: "en_GB"))
    let germanEvening = ZenTimeFormat.string(
      minuteOfDay: 22 * 60 + 30, locale: Locale(identifier: "de_DE"))
    #expect(us.hasPrefix("9:00"))
    #expect(us.contains("AM"))
    #expect(british.hasSuffix("9:00"))
    #expect(!british.contains("AM"))
    #expect(germanEvening == "22:30")
  }

  @Test func timeFormatClampsOutOfRangeMinutes() {
    let locale = Locale(identifier: "en_GB")
    #expect(
      ZenTimeFormat.string(minuteOfDay: -30, locale: locale)
        == ZenTimeFormat.string(minuteOfDay: 0, locale: locale))
    #expect(ZenTimeFormat.string(minuteOfDay: 5000, locale: locale) == "23:59")
  }

  @Test func timeOptionsIncludeOffGridValuesOnce() {
    let options = ZenTimeFormat.options(stepMinutes: 30, including: [545, 540])
    #expect(options.first == 0)
    #expect(options.last == 1410)
    #expect(options.contains(545))
    #expect(options.filter { $0 == 540 }.count == 1)
    #expect(options == options.sorted())
  }

  @Test func sameDayRangesRejectEmptyAndBackwardRanges() {
    #expect(TimeRangeRule.sameDay.issue(start: 540, end: 1080) == nil)
    #expect(TimeRangeRule.sameDay.issue(start: 540, end: 540) == .empty)
    #expect(TimeRangeRule.sameDay.issue(start: 1080, end: 540) == .endBeforeStart)
  }

  @Test func overnightRangesAcceptWrappingButNotEmpty() {
    #expect(TimeRangeRule.allowsOvernight.issue(start: 1320, end: 420) == nil)
    #expect(TimeRangeRule.allowsOvernight.issue(start: 600, end: 600) == .empty)
  }

  @Test func movingStartPastEndPicksTheNextValidEnd() {
    let options = ZenTimeFormat.options(stepMinutes: 30)
    #expect(TimeRangeRule.sameDay.adjustedEnd(start: 1200, end: 1080, options: options) == 1230)
    #expect(TimeRangeRule.sameDay.adjustedEnd(start: 540, end: 1080, options: options) == 1080)
    #expect(TimeRangeRule.allowsOvernight.adjustedEnd(start: 600, end: 600, options: options) == 630)
    #expect(TimeRangeRule.sameDay.isSelectableStart(1410, options: options) == false)
    #expect(TimeRangeRule.allowsOvernight.isSelectableStart(1410, options: options))
  }

  @Test func weekdaysFollowTheCalendarsFirstWeekday() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    calendar.firstWeekday = 1
    #expect(WeekdayOrder.symbols(for: calendar).map(\.weekday) == [1, 2, 3, 4, 5, 6, 7])
    calendar.firstWeekday = 2
    let mondayFirst = WeekdayOrder.symbols(for: calendar)
    #expect(mondayFirst.map(\.weekday) == [2, 3, 4, 5, 6, 7, 1])
    #expect(mondayFirst.first?.fullName == "Monday")
  }

  @Test func weekdayNamesAreLocalized() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "de_DE")
    calendar.firstWeekday = 2
    let symbols = WeekdayOrder.symbols(for: calendar)
    #expect(symbols.first?.fullName == "Montag")
    #expect(symbols.count == 7)
    #expect(symbols.allSatisfy { !$0.shortLabel.isEmpty })
  }

  @Test func togglingKeepsAtLeastOneWeekday() {
    #expect(WeekdayOrder.toggling(3, in: [2, 3]) == [2])
    #expect(WeekdayOrder.toggling(4, in: [2]) == [2, 4])
    #expect(WeekdayOrder.toggling(2, in: [2]) == [2])
    #expect(WeekdayOrder.toggling(9, in: [2]) == [2])
  }
}

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
