import Foundation
import SuperZenCore
import SwiftData
import Testing

@testable import SuperZen

@Suite(.serialized)
@MainActor
final class SuperZenTests {
  // The test target's TEST_HOST is SuperZen.app itself (see project.pbxproj), so
  // `UserDefaults.standard` inside every test IS the real, live app's UserDefaults
  // domain — not an isolated test double. Individual tests historically saved/restored
  // only the couple of keys they touched (see `restoreDefault`, still used below), but
  // that discipline wasn't applied consistently everywhere, and any test that set e.g.
  // `workDuration`/`breakDuration` to a fixture value without restoring it left that
  // value permanently overwriting the real user's setting the next time the app ran.
  // Swift Testing creates a fresh instance of this suite per `@Test`, so snapshotting
  // every known settings key here and restoring it in `deinit` protects every test
  // automatically, regardless of whether that test remembers to clean up after itself.
  private let allSettingsSnapshot: [String: Any?]

  init() {
    let d = UserDefaults.standard
    allSettingsSnapshot = Dictionary(
      uniqueKeysWithValues: SettingKey.allKeys.map { ($0, d.object(forKey: $0)) })
  }

  deinit {
    let d = UserDefaults.standard
    for (key, value) in allSettingsSnapshot {
      if let value {
        d.set(value, forKey: key)
      } else {
        d.removeObject(forKey: key)
      }
    }
  }

  @Test func appRetainsStateManagerAsStateObject() {
    let app = SuperZenApp()
    let labels = Set(Mirror(reflecting: app).children.compactMap(\.label))
    #expect(labels.contains("_stateManager"))
  }

  @Test func sidebarGroupsCoverEachSectionExactlyOnce() {
    let groupedSections = PreferencesSection.sidebarGroups.flatMap(\.sections)
    #expect(groupedSections.count == PreferencesSection.allCases.count)
    #expect(Set(groupedSections).count == PreferencesSection.allCases.count)
    #expect(groupedSections.first == .general)
    #expect(groupedSections.last == .insights)
  }

  @Test func preferencesSectionRawValueRoundTrip() {
    for section in PreferencesSection.allCases {
      #expect(PreferencesSection(rawValue: section.rawValue) == section)
    }
    #expect(PreferencesSection(rawValue: "NotASection") == nil)
  }

  // MARK: - AppStatus Tests

  @Test func appStatusDescriptionMapping() {
    #expect(AppStatus.active.description == "Focusing")
    #expect(AppStatus.nudge.description == "Break soon")
    #expect(AppStatus.onBreak.description == "On Break")
    #expect(AppStatus.wellness(type: .posture).description == "Wellness: Posture")
    #expect(AppStatus.wellness(type: .blink).description == "Wellness: Blink")
    #expect(AppStatus.wellness(type: .water).description == "Wellness: Water")
    #expect(AppStatus.wellness(type: .affirmation).description == "Affirmation")
    #expect(AppStatus.paused.description == "Paused")
  }

  @Test func nudgeDescriptionIsBreakSoon() {
    // Regression: previously fell through to default case and returned "Paused"
    #expect(AppStatus.nudge.description == "Break soon")
    #expect(AppStatus.nudge.description != AppStatus.paused.description)
  }

  @Test func appStatusIsPausedOnlyForPaused() {
    #expect(AppStatus.paused.isPaused == true)
    #expect(AppStatus.active.isPaused == false)
    #expect(AppStatus.nudge.isPaused == false)
    #expect(AppStatus.onBreak.isPaused == false)
    #expect(AppStatus.wellness(type: .posture).isPaused == false)
    #expect(AppStatus.wellness(type: .affirmation).isPaused == false)
  }

  @Test func wellnessTypeDisplayDurations() {
    // posture/blink/water: 0.75s flash — intentionally short for power users
    #expect(AppStatus.WellnessType.posture.displayDuration == 0.75)
    #expect(AppStatus.WellnessType.blink.displayDuration == 0.75)
    #expect(AppStatus.WellnessType.water.displayDuration == 0.75)
    // affirmation: 2.0s — text must be read
    #expect(AppStatus.WellnessType.affirmation.displayDuration == 2.0)
  }

  @Test func wellnessTypeRawValues() {
    #expect(AppStatus.WellnessType.posture.rawValue == "posture")
    #expect(AppStatus.WellnessType.blink.rawValue == "blink")
    #expect(AppStatus.WellnessType.water.rawValue == "water")
    #expect(AppStatus.WellnessType.affirmation.rawValue == "affirmation")
  }

  @Test func appStatusWellnessEquality() {
    #expect(AppStatus.wellness(type: .posture) == AppStatus.wellness(type: .posture))
    #expect(AppStatus.wellness(type: .posture) != AppStatus.wellness(type: .blink))
    #expect(AppStatus.wellness(type: .water) != AppStatus.wellness(type: .affirmation))
    #expect(AppStatus.active != AppStatus.paused)
  }

  // MARK: - BreakDifficulty Tests

  @Test func breakDifficultyAllCasesCount() {
    #expect(BreakDifficulty.allCases.count == 3)
  }

  @Test func breakDifficultyRawValues() {
    #expect(BreakDifficulty.casual.rawValue == "Casual")
    #expect(BreakDifficulty.balanced.rawValue == "Balanced")
    #expect(BreakDifficulty.hardcore.rawValue == "Hardcore")
  }

  @Test func breakDifficultyRoundTrip() {
    for difficulty in BreakDifficulty.allCases {
      #expect(BreakDifficulty(rawValue: difficulty.rawValue) == difficulty)
    }
    #expect(BreakDifficulty(rawValue: "unknown") == nil)
  }

  // MARK: - PruneSummary

  @Test func pruneSummaryTotalDeletedIsCorrectSum() {
    let s = TelemetryService.PruneSummary(
      sessionsDeleted: 5, breaksDeleted: 3, wellnessDeleted: 7, appUsageDeleted: 2)
    #expect(s.totalDeleted == 17)
  }

  @Test func pruneSummaryZeroTotalWhenAllZero() {
    let s = TelemetryService.PruneSummary(
      sessionsDeleted: 0, breaksDeleted: 0, wellnessDeleted: 0, appUsageDeleted: 0)
    #expect(s.totalDeleted == 0)
  }

  // MARK: - SettingsCatalog Tests

  @Test func settingsCatalogWorkDurationOptionsAllPositive() {
    #expect(!SettingsCatalog.workDurationOptions.isEmpty)
    for (label, duration) in SettingsCatalog.workDurationOptions {
      #expect(!label.isEmpty)
      #expect(duration > 0)
    }
  }

  @Test func settingsCatalogBreakDurationOptionsAllPositive() {
    #expect(!SettingsCatalog.breakDurationOptions.isEmpty)
    for (label, duration) in SettingsCatalog.breakDurationOptions {
      #expect(!label.isEmpty)
      #expect(duration > 0)
    }
  }

  @Test func settingsCatalogBalancedSkipLockRatiosInValidRange() {
    #expect(!SettingsCatalog.balancedSkipLockOptions.isEmpty)
    for (_, ratio) in SettingsCatalog.balancedSkipLockOptions {
      #expect(ratio > 0.0 && ratio < 1.0)
    }
  }

  @Test func settingsCatalogWellnessMultipliersInValidRange() {
    for (_, multiplier) in SettingsCatalog.wellnessDurationMultiplierOptions {
      #expect(multiplier >= 0.1 && multiplier <= 2.0)
    }
  }

  @Test func settingsCatalogRetentionDaysAllPositive() {
    for days in SettingsCatalog.retentionDaysOptions {
      #expect(days > 0)
    }
  }

  @Test func settingsCatalogDayProgressBarStylesAreKnownKeys() {
    let valid = Set(["bar_label", "bar_only", "label_only", "bar_label_inside"])
    for (_, key) in SettingsCatalog.dayProgressBarStyles {
      #expect(valid.contains(key))
    }
  }

  @Test func settingsCatalogDayProgressMetricsAreKnownKeys() {
    let valid = Set([
      "pct_done", "pct_remaining", "min_elapsed", "min_remaining",
      "hr_elapsed", "hr_remaining", "hr_min_elapsed", "hr_min_remaining",
    ])
    for (_, key) in SettingsCatalog.dayProgressMetrics {
      #expect(valid.contains(key))
    }
  }

  @Test func settingsCatalogScoringProfilesAreValid() {
    #expect(Set(SettingsCatalog.scoringProfiles) == Set(["Balanced", "Deep Focus", "Recovery"]))
  }

  // MARK: - Bug-fix regression tests

  @Test func registerDefaultsDoesNotOverrideExistingUserValues() {
    let defaults = UserDefaults.standard
    let prevWork = defaults.object(forKey: SettingKey.workDuration)
    defer { restoreDefault(prevWork, key: SettingKey.workDuration) }

    defaults.set(9999.0, forKey: SettingKey.workDuration)
    SettingKey.registerDefaults()  // must NOT overwrite the 9999

    #expect(defaults.double(forKey: SettingKey.workDuration) == 9999.0)
  }

  /// Regression test for a real gap: `customImagePath` was declared as a `SettingKey` and
  /// listed in `allKeys`, but had no entry in `registerDefaults()`'s dictionary literal, so a
  /// fresh install would read `nil` for it instead of a documented default. Registering into
  /// an isolated, guaranteed-empty UserDefaults suite (rather than `.standard`, which already
  /// has persisted values from prior test/app runs that would mask a missing registration)
  /// proves every key in `allKeys` actually gets a registered fallback.
  @Test func registerDefaultsRegistersEveryKey() {
    let suiteName = "com.himudigonda.SuperZenTests.registerDefaultsCompleteness"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    SettingKey.registerDefaults(in: defaults)

    for key in SettingKey.allKeys {
      #expect(defaults.object(forKey: key) != nil, "\(key) has no registered default")
    }
  }

  // MARK: - Onboarding gate

  @Test func onboardingDefaultsToNotCompleted() {
    let defaults = UserDefaults.standard
    let prev = defaults.object(forKey: SettingKey.hasCompletedOnboarding)
    defer { restoreDefault(prev, key: SettingKey.hasCompletedOnboarding) }

    // A fresh install (key absent) must default to showing onboarding.
    defaults.removeObject(forKey: SettingKey.hasCompletedOnboarding)
    SettingKey.registerDefaults()
    #expect(defaults.bool(forKey: SettingKey.hasCompletedOnboarding) == false)
  }

  private func restoreDefault(_ previousValue: Any?, key: String) {
    if let value = previousValue {
      UserDefaults.standard.set(value, forKey: key)
    } else {
      UserDefaults.standard.removeObject(forKey: key)
    }
  }
}
