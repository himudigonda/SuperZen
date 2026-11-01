import Foundation
import Testing

@testable import SuperZen

private struct CatalogFile {
  static let languages = ["en", "es", "fr", "de"]

  let strings: [String: [String: Any]]

  init() throws {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("SuperZen/Localizable.xcstrings")
    let root = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    strings = try #require(root["strings"] as? [String: [String: Any]])
  }

  func localizations(_ key: String) -> [String: [String: Any]] {
    strings[key]?["localizations"] as? [String: [String: Any]] ?? [:]
  }

  func values(_ key: String, language: String) -> [String] {
    guard let entry = localizations(key)[language] else { return [] }
    if let unit = entry["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
      return [value]
    }
    let plural = (entry["variations"] as? [String: Any])?["plural"] as? [String: [String: Any]]
    return (plural ?? [:]).values.compactMap {
      ($0["stringUnit"] as? [String: Any])?["value"] as? String
    }
  }

  func isPlural(_ key: String, language: String) -> Bool {
    let entry = localizations(key)[language]
    return (entry?["variations"] as? [String: Any])?["plural"] != nil
  }
}

private func placeholders(_ text: String) -> [String] {
  let pattern = #/%(?:\d\$)?(lld|@)/#
  return text.matches(of: pattern).map { String($0.output.1) }.sorted()
}

private func localizedBundle(_ language: String) throws -> Bundle {
  let url = try #require(Bundle.main.url(forResource: language, withExtension: "lproj"))
  return try #require(Bundle(url: url))
}

struct StringCatalogTests {
  static let countedKeys = [
    "%lld breaks",
    "%lld reminders",
    "%lld days",
    "%lld minute",
    "%lld second",
    "%lld mins without a break",
    "Deleted %lld records. Insights start fresh from now.",
    "Skip available in %lld seconds",
  ]

  static let optionLabels: [String] = {
    let numeric = [
      SettingsCatalog.workDurationOptions, SettingsCatalog.breakDurationOptions,
      SettingsCatalog.longBreakDurationOptions, SettingsCatalog.typingDeferralCapOptions,
      SettingsCatalog.reminderLeadTimeOptions, SettingsCatalog.reminderDurationOptions,
      SettingsCatalog.balancedSkipLockOptions, SettingsCatalog.commonWellnessFrequencyOptions,
      SettingsCatalog.affirmationFrequencyOptions,
      SettingsCatalog.wellnessDurationMultiplierOptions, SettingsCatalog.idleThresholdOptions,
      SettingsCatalog.interruptionThresholdOptions,
    ].flatMap { $0.map(\.0) }
    let tokens = (SettingsCatalog.dayProgressBarStyles + SettingsCatalog.dayProgressMetrics)
      .map(\.0)
    return numeric + tokens + SettingsCatalog.dayProgressFillsOptions.map(\.0)
  }()

  @Test func everyEntryIsTranslated() throws {
    let catalog = try CatalogFile()
    #expect(!catalog.strings.isEmpty)
    for key in catalog.strings.keys {
      let missing = CatalogFile.languages.filter { catalog.values(key, language: $0).isEmpty }
      #expect(missing.isEmpty, "\(key) has no \(missing) translation")
    }
  }

  @Test func translationsKeepTheKeyPlaceholders() throws {
    let catalog = try CatalogFile()
    for key in catalog.strings.keys {
      for language in CatalogFile.languages {
        for value in catalog.values(key, language: language) where !value.contains("%#@") {
          #expect(
            placeholders(value) == placeholders(key), "\(language) \(key) became \(value)")
        }
      }
    }
  }

  @Test(arguments: countedKeys)
  func countsArePluralised(_ key: String) throws {
    let catalog = try CatalogFile()
    for language in CatalogFile.languages {
      #expect(catalog.isPlural(key, language: language), "\(key) is not plural in \(language)")
    }
  }

  @Test func settingsOptionLabelsAreInTheCatalog() throws {
    let catalog = try CatalogFile()
    let missing = Self.optionLabels.filter { catalog.strings[$0] == nil }
    #expect(missing.isEmpty, "Untranslated option labels: \(missing)")
  }

  @Test func optionLabelsResolveFromTheBuiltCatalog() throws {
    let spanish = try localizedBundle("es")
    #expect(OptionLabel.localized("20 minutes", bundle: spanish) == "20 minutos")
    #expect(OptionLabel.localized("20% of break", bundle: spanish) == "20 % de la pausa")
    #expect(OptionLabel.localized("Not in the catalog", bundle: spanish) == "Not in the catalog")
  }

  @Test func pluralsResolveFromTheBuiltCatalog() throws {
    let german = try localizedBundle("de")
    let one = String(localized: "\(1) breaks", bundle: german, locale: Locale(identifier: "de"))
    let many = String(localized: "\(4) breaks", bundle: german, locale: Locale(identifier: "de"))
    #expect(one == "1 Pause")
    #expect(many == "4 Pausen")
  }
}
