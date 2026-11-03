import Foundation
import Testing

@testable import SuperZen

@MainActor private func makeSuite() -> (UserDefaults, String) {
  let name = "com.himudigonda.SuperZenTests.reset.\(UUID().uuidString)"
  let suite = UserDefaults(suiteName: name)!
  SettingKey.registerDefaults(in: suite)
  return (suite, name)
}

private func sameValue(_ lhs: Any?, _ rhs: Any?) -> Bool {
  switch (lhs, rhs) {
  case (nil, nil): return true
  case (let left as NSObject, let right as NSObject): return left.isEqual(right)
  default: return false
  }
}

@MainActor
struct SettingsResetTests {
  static let knownPendingKeys: Set<String> = [
    "breakTipsEnabled", "breakPresentation", "appUsageTrackingEnabled",
    "deferralDuringCalls", "deferralDuringFullscreen",
  ]

  @Test(arguments: PreferencesSection.allCases.filter { $0 != .about && $0 != .insights })
  func resetRestoresDefaultsForOnlyThatSection(_ section: PreferencesSection) {
    let (suite, name) = makeSuite()
    defer { suite.removePersistentDomain(forName: name) }
    let (pristine, pristineName) = makeSuite()
    defer { pristine.removePersistentDomain(forName: pristineName) }

    for key in SettingKey.allKeys { suite.set("changed", forKey: key) }
    SettingsSections.reset(section, in: suite)

    for key in section.settingKeys {
      #expect(sameValue(suite.object(forKey: key), pristine.object(forKey: key)), "\(key) in \(section)")
    }
    let others = Set(SettingKey.allKeys).subtracting(section.settingKeys)
    for key in others {
      #expect(suite.string(forKey: key) == "changed", "\(key) must survive a reset of \(section)")
    }
  }

  @Test func protectedKeysSurviveEverySectionReset() {
    let (suite, name) = makeSuite()
    defer { suite.removePersistentDomain(forName: name) }
    suite.set(true, forKey: SettingKey.hasCompletedOnboarding)
    suite.set(true, forKey: SettingKey.launchAtLogin)
    suite.set(7, forKey: SettingKey.wellnessCadenceVersion)
    for section in PreferencesSection.allCases { SettingsSections.reset(section, in: suite) }
    #expect(suite.bool(forKey: SettingKey.hasCompletedOnboarding))
    #expect(suite.bool(forKey: SettingKey.launchAtLogin))
    #expect(suite.integer(forKey: SettingKey.wellnessCadenceVersion) == 7)
  }

  @Test func everyKeyBelongsToExactlyOneSectionOrIsExempt() {
    let sectionKeys = PreferencesSection.allCases.flatMap(\.settingKeys)
    #expect(Set(sectionKeys).count == sectionKeys.count)
    #expect(Set(sectionKeys).isDisjoint(with: SettingsSections.exemptKeys))
    #expect(Set(sectionKeys).isSubset(of: Set(SettingKey.allKeys)))
    let uncovered = Set(SettingKey.allKeys).subtracting(sectionKeys).subtracting(SettingsSections.exemptKeys)
    #expect(uncovered.subtracting(Self.knownPendingKeys).isEmpty, "unmapped keys: \(uncovered)")
  }

  @Test func neverResettableKeysAreExempt() {
    for key in [SettingKey.hasCompletedOnboarding, SettingKey.launchAtLogin, SettingKey.wellnessCadenceVersion] {
      #expect(SettingsSections.exemptKeys.contains(key))
    }
  }
}
