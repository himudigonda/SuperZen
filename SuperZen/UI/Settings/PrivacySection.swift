import SwiftUI

struct PrivacySection: View {
  @AppStorage(SettingKey.appUsageTrackingEnabled) private var appUsageTrackingEnabled = true

  var body: some View {
    PageSection("Privacy") {
      Card {
        LabeledToggle(
          String(localized: "Track app usage during focus", comment: "Privacy settings row title"),
          subtitle: String(
            localized: "Records which apps you use in each work block. Turning this off keeps existing history.",
            comment: "Privacy settings row subtitle for app usage tracking"),
          isOn: $appUsageTrackingEnabled)
      }
    }
  }
}
