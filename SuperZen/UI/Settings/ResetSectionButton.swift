import SwiftUI

struct ResetSectionButton: View {
  let section: PreferencesSection
  @State private var confirming = false

  var body: some View {
    if !section.settingKeys.isEmpty {
      HStack {
        Spacer(minLength: 0)
        Button(String(localized: "Reset this page to defaults", comment: "Settings reset button")) {
          confirming = true
        }
        .buttonStyle(ZenButtonStyle(kind: .text, size: .small))
      }
      .zenDialog(isPresented: $confirming) {
        ZenDialogSurface(
          title: String(
            localized: "Reset \(section.localizedTitle) settings?",
            comment: "Settings reset confirmation title with the page name"),
          message: String(
            localized: "Every option on this page returns to its default. Other pages are not changed.",
            comment: "Settings reset confirmation message")
        ) {
          EmptyView()
        } actions: {
          Button(String(localized: "Cancel", comment: "Cancel button")) {
            confirming = false
          }
          .buttonStyle(.zenText)
          Button(String(localized: "Reset", comment: "Settings reset confirm button")) {
            confirming = false
            SettingsSections.reset(section)
          }
          .buttonStyle(.zenDestructive)
        }
      }
    }
  }
}
