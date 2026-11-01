import Foundation
import SuperZenCore
import Testing

@testable import SuperZen

private func isolatedDefaults() -> (UserDefaults, String) {
  let name = "com.himudigonda.SuperZenTests.catalog.\(UUID().uuidString)"
  return (UserDefaults(suiteName: name)!, name)
}

struct NumericOptions: Sendable, CustomTestStringConvertible {
  let name: String
  let defaultValue: Double
  let options: [(String, Double)]
  let range: ClosedRange<Double>

  var testDescription: String { name }
}

struct TokenOptions: Sendable, CustomTestStringConvertible {
  let name: String
  let defaultValue: String
  let options: [String]

  var testDescription: String { name }
}

private func counts(_ values: [Int]) -> [(String, Double)] {
  values.map { ("\($0)", Double($0)) }
}

struct SettingsCatalogTests {
  static let numeric: [NumericOptions] = [
    NumericOptions(
      name: "work", defaultValue: SettingsCatalog.workDurationDefault,
      options: SettingsCatalog.workDurationOptions, range: 60...14_400),
    NumericOptions(
      name: "break", defaultValue: SettingsCatalog.breakDurationDefault,
      options: SettingsCatalog.breakDurationOptions, range: 5...3600),
    NumericOptions(
      name: "nudge lead", defaultValue: SettingsCatalog.nudgeLeadTimeDefault,
      options: SettingsCatalog.reminderLeadTimeOptions, range: 1...300),
    NumericOptions(
      name: "reminder", defaultValue: SettingsCatalog.reminderDurationDefault,
      options: SettingsCatalog.reminderDurationOptions, range: 1...120),
    NumericOptions(
      name: "skip lock ratio", defaultValue: SettingsCatalog.balancedSkipLockRatioDefault,
      options: SettingsCatalog.balancedSkipLockOptions,
      range: SettingsCatalog.balancedSkipLockRatioClamp),
    NumericOptions(
      name: "posture", defaultValue: SettingsCatalog.postureFrequencyDefault,
      options: SettingsCatalog.commonWellnessFrequencyOptions, range: 60...14_400),
    NumericOptions(
      name: "blink", defaultValue: SettingsCatalog.blinkFrequencyDefault,
      options: SettingsCatalog.commonWellnessFrequencyOptions, range: 60...14_400),
    NumericOptions(
      name: "long wellness", defaultValue: SettingsCatalog.longWellnessFrequencyDefault,
      options: SettingsCatalog.commonWellnessFrequencyOptions, range: 60...14_400),
    NumericOptions(
      name: "affirmation", defaultValue: SettingsCatalog.longWellnessFrequencyDefault,
      options: SettingsCatalog.affirmationFrequencyOptions, range: 60...14_400),
    NumericOptions(
      name: "wellness multiplier", defaultValue: SettingsCatalog.wellnessDurationMultiplierDefault,
      options: SettingsCatalog.wellnessDurationMultiplierOptions,
      range: SettingsCatalog.wellnessDurationMultiplierClamp),
    NumericOptions(
      name: "idle", defaultValue: SettingsCatalog.idleThresholdDefault,
      options: SettingsCatalog.idleThresholdOptions, range: 1...600),
    NumericOptions(
      name: "interruption", defaultValue: SettingsCatalog.interruptionThresholdDefault,
      options: SettingsCatalog.interruptionThresholdOptions, range: 1...600),
    NumericOptions(
      name: "focus goal", defaultValue: Double(SettingsCatalog.dailyFocusGoalDefault),
      options: counts(SettingsCatalog.dailyFocusGoalOptions), range: 1...1440),
    NumericOptions(
      name: "break goal", defaultValue: Double(SettingsCatalog.dailyBreakGoalDefault),
      options: counts(SettingsCatalog.dailyBreakGoalOptions), range: 1...100),
    NumericOptions(
      name: "wellness goal", defaultValue: Double(SettingsCatalog.dailyWellnessGoalDefault),
      options: counts(SettingsCatalog.dailyWellnessGoalOptions), range: 1...100),
    NumericOptions(
      name: "retention", defaultValue: Double(SettingsCatalog.dataRetentionDaysDefault),
      options: counts(SettingsCatalog.retentionDaysOptions), range: 1...3650),
  ]

  static let tokens: [TokenOptions] = [
    TokenOptions(
      name: "accent", defaultValue: SettingsCatalog.accentPaletteDefault,
      options: SettingsCatalog.accentPalettes),
    TokenOptions(
      name: "contrast", defaultValue: SettingsCatalog.contrastProfileDefault,
      options: SettingsCatalog.contrastProfiles),
    TokenOptions(
      name: "scoring", defaultValue: SettingsCatalog.scoringProfileDefault,
      options: SettingsCatalog.scoringProfiles),
    TokenOptions(
      name: "menu bar", defaultValue: SettingsCatalog.menuBarDisplayDefault,
      options: SettingsCatalog.menuBarDisplayOptions),
    TokenOptions(
      name: "timer style", defaultValue: SettingsCatalog.timerStyleDefault,
      options: SettingsCatalog.timerStyleOptions),
    TokenOptions(
      name: "break background", defaultValue: SettingsCatalog.breakBackgroundDefault,
      options: SettingsCatalog.breakBackgroundOptions),
    TokenOptions(
      name: "alert position", defaultValue: SettingsCatalog.alertPositionDefault,
      options: SettingsCatalog.alertPositionOptions),
    TokenOptions(
      name: "progress style", defaultValue: SettingsCatalog.dayProgressBarStyleDefault,
      options: SettingsCatalog.dayProgressBarStyles.map(\.1)),
    TokenOptions(
      name: "progress metric", defaultValue: SettingsCatalog.dayProgressMetricDefault,
      options: SettingsCatalog.dayProgressMetrics.map(\.1)),
  ]

  @Test(arguments: numeric)
  func numericOptionsAreSaneAndIncludeTheDefault(_ catalog: NumericOptions) {
    let values = catalog.options.map(\.1)
    #expect(values.contains(catalog.defaultValue))
    #expect(values == values.sorted())
    #expect(Set(values).count == values.count)
    #expect(values.allSatisfy(catalog.range.contains))
    #expect(catalog.options.allSatisfy { !$0.0.isEmpty })
  }

  @Test(arguments: tokens)
  func tokenOptionsAreUniqueAndIncludeTheDefault(_ catalog: TokenOptions) {
    #expect(catalog.options.contains(catalog.defaultValue))
    #expect(Set(catalog.options).count == catalog.options.count)
    #expect(catalog.options.allSatisfy { !$0.isEmpty })
  }

  @Test func everyTokenHasItsOwnDisplayName() {
    let catalogs: [(tokens: [String], fallback: String, displayName: (String) -> String)] = [
      (SettingsCatalog.accentPalettes, SettingsCatalog.accentPaletteDefault,
       SettingsCatalog.accentPaletteDisplayName),
      (SettingsCatalog.contrastProfiles, SettingsCatalog.contrastProfileDefault,
       SettingsCatalog.contrastProfileDisplayName),
      (SettingsCatalog.scoringProfiles, SettingsCatalog.scoringProfileDefault,
       SettingsCatalog.scoringProfileDisplayName),
      (SettingsCatalog.menuBarDisplayOptions, SettingsCatalog.menuBarDisplayDefault,
       SettingsCatalog.menuBarDisplayName),
    ]
    for catalog in catalogs {
      #expect(Set(catalog.tokens.map(catalog.displayName)).count == catalog.tokens.count)
      #expect(catalog.displayName("Unknown") == catalog.displayName(catalog.fallback))
    }
  }
}

@MainActor
struct SettingKeyTests {
  @Test func everyKeyIsUniqueAndRegistered() {
    let (defaults, name) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: name) }

    SettingKey.registerDefaults(in: defaults)

    #expect(Set(SettingKey.allKeys).count == SettingKey.allKeys.count)
    for key in SettingKey.allKeys {
      #expect(defaults.object(forKey: key) != nil, "\(key) has no registered default")
    }
  }

  @Test func registeredDefaultsMatchTheEngineDefaults() {
    let (defaults, name) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: name) }

    SettingKey.registerDefaults(in: defaults)

    let timer = TimerSettings()
    #expect(defaults.double(forKey: SettingKey.workDuration) == timer.workDuration)
    #expect(defaults.double(forKey: SettingKey.breakDuration) == timer.shortBreakDuration)
    #expect(defaults.string(forKey: SettingKey.difficulty) == BreakDifficulty.balanced.rawValue)
    #expect(defaults.bool(forKey: SettingKey.hasCompletedOnboarding) == false)
  }

  @Test func registeringNeverOverridesAStoredValue() {
    let (defaults, name) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: name) }

    defaults.set(9999.0, forKey: SettingKey.workDuration)
    defaults.set(true, forKey: SettingKey.hasCompletedOnboarding)
    SettingKey.registerDefaults(in: defaults)

    #expect(defaults.double(forKey: SettingKey.workDuration) == 9999)
    #expect(defaults.bool(forKey: SettingKey.hasCompletedOnboarding))
  }
}

@MainActor
struct AppShellTests {
  @Test func appRetainsStateManagerAsStateObject() {
    let labels = Set(Mirror(reflecting: SuperZenApp()).children.compactMap(\.label))
    #expect(labels.contains("_stateManager"))
  }

  @Test func sidebarListsEverySectionOnceInOrder() {
    let grouped = PreferencesSection.sidebarGroups.flatMap(\.sections)
    #expect(grouped.count == PreferencesSection.allCases.count)
    #expect(Set(grouped) == Set(PreferencesSection.allCases))
    #expect(grouped.first == .general)
    #expect(grouped.last == .insights)
  }

  @Test(arguments: PreferencesSection.allCases)
  func sectionsRoundTripThroughTheirRawValue(_ section: PreferencesSection) {
    #expect(PreferencesSection(rawValue: section.rawValue) == section)
  }
}
