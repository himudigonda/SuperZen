import SuperZenCore
import SwiftUI

struct AdvancedSettingsView: View {
  @AppStorage(SettingKey.balancedSkipLockRatio) private var balancedSkipLockRatio: Double = SettingsCatalog
    .balancedSkipLockRatioDefault
  @AppStorage(SettingKey.dataRetentionEnabled) private var dataRetentionEnabled = true
  @AppStorage(SettingKey.dataRetentionDays) private var dataRetentionDays = SettingsCatalog.dataRetentionDaysDefault
  @State private var pruneStatusMessage = String(
    localized: "Retention cleanup runs automatically on launch.",
    comment: "Advanced settings: default status message before a manual prune has run")

  var body: some View {
    SettingsPage {
      CardSection("Break enforcement") {
        SettingRow(
          String(localized: "Balanced mode lock window", comment: "Advanced settings row title"),
          subtitle: String(
            localized: "How much of each break must pass before skipping is allowed",
            comment: "Advanced settings row subtitle for balanced mode lock window")
        ) {
          MenuPicker(
            String(localized: "Balanced mode lock window", comment: "Advanced settings row title"),
            selection: $balancedSkipLockRatio,
            catalog: SettingsCatalog.balancedSkipLockOptions)
        }
      }

      PrivacySection()

      PageSection("Analytics retention") {
        Card {
          LabeledToggle(
            String(localized: "Enable retention policy", comment: "Advanced settings row title"),
            subtitle: String(
              localized: "Automatically prune telemetry older than the configured window",
              comment: "Advanced settings row subtitle for retention policy"),
            isOn: $dataRetentionEnabled)
          CardDivider()
          Group {
            SettingRow(
              String(localized: "Retain telemetry for", comment: "Advanced settings row title")
            ) {
              MenuPicker(
                String(localized: "Retain telemetry for", comment: "Advanced settings row title"),
                selection: $dataRetentionDays,
                options: SettingsCatalog.retentionDaysOptions,
                label: {
                  String(localized: "\($0) days", comment: "Retention window option, plural count")
                })
            }
            CardDivider()
            SettingRow(String(localized: "Run cleanup now", comment: "Advanced settings row title")) {
              PillButton(String(localized: "Prune Data", comment: "Advanced settings button")) {
                prune()
              }
            }
          }
          .disabled(!dataRetentionEnabled)
        }

        Text(pruneStatusMessage)
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
      }
    }
  }

  private func prune() {
    let summary = TelemetryService.shared.pruneHistoricalData(retainingDays: dataRetentionDays)
    pruneStatusMessage = String(
      localized:
        "Deleted \(summary.totalDeleted) records (\(summary.sessionsDeleted) sessions, \(summary.breaksDeleted) breaks, \(summary.wellnessDeleted) wellness, \(summary.appUsageDeleted) app-usage rows).",
      comment: "Status message after pruning telemetry, with per-category counts")
  }
}
