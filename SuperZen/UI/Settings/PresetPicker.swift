import SuperZenCore
import SwiftUI

extension SettingsPreset {
  var title: String {
    switch self {
    case .eyes2020: return String(localized: "20-20-20", comment: "Schedule preset name")
    case .pomodoro: return String(localized: "Pomodoro", comment: "Schedule preset name")
    case .deepWork: return String(localized: "Deep work", comment: "Schedule preset name")
    case .gentle: return String(localized: "Gentle", comment: "Schedule preset name")
    }
  }

  var summary: String {
    switch self {
    case .eyes2020:
      return String(
        localized: "20 min work, 20 sec eye rest", comment: "Schedule preset description")
    case .pomodoro:
      return String(localized: "25 min work, 5 min break", comment: "Schedule preset description")
    case .deepWork:
      return String(
        localized: "50 min work, 10 min break", comment: "Schedule preset description")
    case .gentle:
      return String(
        localized: "45 min work, easy to skip", comment: "Schedule preset description")
    }
  }

  var storedValues: [String: Any] {
    var values: [String: Any] = [
      SettingKey.workDuration: workDuration,
      SettingKey.breakDuration: shortBreakDuration,
      SettingKey.longBreakEvery: longBreakEvery,
      SettingKey.difficulty: difficulty.rawValue,
    ]
    if let longBreakDuration { values[SettingKey.longBreakDuration] = longBreakDuration }
    return values
  }

  func write(to defaults: UserDefaults) {
    for (key, value) in storedValues { defaults.set(value, forKey: key) }
  }

  static func active(in defaults: UserDefaults) -> SettingsPreset? {
    matching(LegacySettingsMigration.migrate { defaults.object(forKey: $0) })
  }
}

struct PresetPicker: View {
  @AppStorage(SettingKey.workDuration) private var workDuration: Double = SettingsCatalog.workDurationDefault
  @AppStorage(SettingKey.breakDuration) private var breakDuration: Double = SettingsCatalog.breakDurationDefault
  @AppStorage(SettingKey.longBreakDuration) private var longBreakDuration: Double = SettingsCatalog
    .longBreakDurationDefault
  @AppStorage(SettingKey.longBreakEvery) private var longBreakEvery = SettingsCatalog.longBreakEveryDefault
  @AppStorage(SettingKey.difficulty) private var difficultyRaw = BreakDifficulty.balanced.rawValue

  private var active: SettingsPreset? {
    _ = (workDuration, breakDuration, longBreakDuration, longBreakEvery, difficultyRaw)
    return SettingsPreset.active(in: .standard)
  }

  var body: some View {
    PageSection(
      String(localized: "Presets", comment: "Break schedule section title"),
      subtitle: String(
        localized: "Start from a proven rhythm, then fine-tune below.",
        comment: "Break schedule presets subtitle")
    ) {
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 150), spacing: ZenSpacing.md, alignment: .top)],
        spacing: ZenSpacing.md
      ) {
        ForEach(SettingsPreset.allCases) { preset in
          PresetTile(preset: preset, isSelected: active == preset) {
            preset.write(to: .standard)
          }
        }
      }
    }
  }
}

private struct PresetTile: View {
  let preset: SettingsPreset
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
        Text(preset.title)
          .font(ZenFont.labelLarge)
          .foregroundStyle(ZenColor.onSurface)
        Text(preset.summary)
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
          .lineLimit(2, reservesSpace: true)
      }
      .padding(ZenSpacing.sm)
      .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
      .zenSurface(isSelected: isSelected)
    }
    .buttonStyle(.zenCard)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(preset.title). \(preset.summary)")
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}
