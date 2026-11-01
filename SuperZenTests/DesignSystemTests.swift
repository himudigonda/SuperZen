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

  @Test(arguments: ContrastProfile.allCases)
  func bodyTextMeetsWCAGAAOnCanvasInBothSchemes(_ profile: ContrastProfile) {
    let theme = ZenTheme(accent: .ocean, contrast: profile)
    for scheme in schemes {
      let canvas = theme.rgba(.canvas, scheme: scheme)
      #expect(theme.rgba(.textPrimary, scheme: scheme).contrastRatio(against: canvas) >= 7)
      #expect(theme.rgba(.textSecondary, scheme: scheme).contrastRatio(against: canvas) >= 4.5)
      #expect(theme.rgba(.textTertiary, scheme: scheme).contrastRatio(against: canvas) >= 4.5)
    }
  }

  @Test(arguments: AccentPalette.allCases)
  func accentMeetsNonTextContrastInBothSchemes(_ palette: AccentPalette) {
    let theme = ZenTheme(accent: palette, contrast: .balanced)
    for scheme in schemes {
      let canvas = theme.rgba(.canvas, scheme: scheme)
      #expect(theme.rgba(.accent, scheme: scheme).contrastRatio(against: canvas) >= 3)
    }
  }

  @Test(arguments: [ZenColorRole.success, .warning, .danger, .info])
  func statusColorsMeetNonTextContrastInBothSchemes(_ role: ZenColorRole) {
    for scheme in schemes {
      let canvas = ZenTheme.standard.rgba(.canvas, scheme: scheme)
      #expect(ZenTheme.standard.rgba(role, scheme: scheme).contrastRatio(against: canvas) >= 3)
    }
  }

  @Test func lightAndDarkResolveDifferentlyForAdaptiveRoles() {
    for role in [ZenColorRole.canvas, .textPrimary, .textSecondary, .surfaceTop, .accent] {
      #expect(ZenTheme.standard.rgba(role, scheme: .light) != ZenTheme.standard.rgba(role, scheme: .dark))
    }
  }

  @Test func overlayRolesIgnoreTheColorScheme() {
    for role in [ZenColorRole.overlayText, .overlaySurface, .overlayStroke, .overlayScrim] {
      #expect(ZenTheme.standard.rgba(role, scheme: .light) == ZenTheme.standard.rgba(role, scheme: .dark))
    }
  }

  @Test func contrastProfilesOrderStrokeAndSurfaceStrength() {
    for scheme in schemes {
      let alphas = ContrastProfile.allCases.map {
        ZenTheme(accent: .ocean, contrast: $0).rgba(.surfaceStroke, scheme: scheme).alpha
      }
      #expect(alphas == alphas.sorted())
      #expect(Set(alphas).count == alphas.count)
      let high = ZenTheme(accent: .ocean, contrast: .high)
      #expect(high.rgba(.textSecondary, scheme: scheme).alpha == 1)
    }
  }

  @Test func systemIncreasedContrastEscalatesToHigh() {
    for profile in ContrastProfile.allCases {
      #expect(profile.escalated(systemIncreasedContrast: true) == .high)
      #expect(profile.escalated(systemIncreasedContrast: false) == profile)
    }
  }

  @Test func accentPaletteChangesOnlyAccentRoles() {
    let ocean = ZenTheme(accent: .ocean, contrast: .balanced)
    let sunset = ZenTheme(accent: .sunset, contrast: .balanced)
    #expect(ocean.rgba(.accent, scheme: .light) != sunset.rgba(.accent, scheme: .light))
    #expect(ocean.rgba(.textPrimary, scheme: .light) == sunset.rgba(.textPrimary, scheme: .light))
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
    #expect(ZenElevation.flat.shadowStrength == 0)
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
