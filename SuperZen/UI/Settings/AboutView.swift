import SuperZenCore
import SwiftUI

struct AboutView: View {
  let stateManager: StateManager
  @State private var copied = false
  private let appVersion =
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
  private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "16"

  var body: some View {
    VStack(spacing: ZenSpacing.xxl) {
      Spacer().frame(height: ZenSpacing.lg)

      ZStack {
        Circle()
          .fill(ZenColor.primary)
          .frame(width: 100, height: 100)
          .zenElevation(.level3)
        Image(systemName: "eye.fill")
          .font(ZenFont.heroIcon)
          .foregroundStyle(ZenColor.onPrimary)
      }
      .accessibilityHidden(true)

      VStack(spacing: ZenSpacing.xs) {
        Text(verbatim: "SuperZen")
          .font(ZenFont.headlineSmall)
          .foregroundStyle(ZenColor.onSurface)
          .accessibilityAddTraits(.isHeader)
        Text("by Himansh Mudigonda (@himudigonda)")
          .font(ZenFont.bodyMedium)
          .foregroundStyle(ZenColor.onSurfaceVariant)
        Text("Version \(appVersion) (\(buildNumber))")
          .font(ZenFont.bodyMedium)
          .foregroundStyle(ZenColor.onSurfaceVariant)
      }

      Card {
        linkRow(
          String(localized: "Website", comment: "About screen row title: website link"),
          label: String(localized: "Visit", comment: "About screen link label"),
          address: "https://himudigonda.me")
        CardDivider()
        linkRow(
          String(localized: "GitHub", comment: "About screen row title: GitHub link"),
          label: "@himudigonda",
          address: "https://github.com/himudigonda")
        CardDivider()
        linkRow(
          String(localized: "LinkedIn", comment: "About screen row title: LinkedIn link"),
          label: String(localized: "Connect", comment: "About screen link label"),
          address: "https://linkedin.com/in/himudigonda")
        CardDivider()
        linkRow(
          String(localized: "Support", comment: "About screen row title: support contact"),
          label: "himudigonda@gmail.com",
          address: "mailto:himudigonda@gmail.com")
        CardDivider()
        SettingRow(
          String(localized: "Copy diagnostics", comment: "About screen row title"),
          subtitle: copied
            ? String(localized: "Copied to the clipboard", comment: "About screen diagnostics confirmation")
            : String(
              localized: "Version, settings and record counts. No file paths or app names.",
              comment: "About screen diagnostics row subtitle")
        ) {
          PillButton(String(localized: "Copy", comment: "About screen copy button")) {
            Diagnostics.copyToPasteboard(phaseLabel: stateManager.menuBar.glyph.title)
            copied = true
          }
        }
        .task(id: copied) {
          guard copied else { return }
          try? await Task.sleep(for: .seconds(3))
          copied = false
        }
      }

      Spacer()

      Text("Google Sans is licensed under the SIL Open Font License 1.1.")
        .font(ZenFont.bodySmall)
        .foregroundStyle(ZenColor.onSurfaceVariant)

      HStack(spacing: ZenSpacing.xxs) {
        Text("Please take care of yourself")
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
        Image(systemName: "heart.fill")
          .font(ZenFont.iconSmall)
          .foregroundStyle(ZenColor.primary)
          .accessibilityHidden(true)
      }
      .padding(.bottom, ZenSpacing.lg)
    }
  }

  @ViewBuilder
  private func linkRow(_ title: String, label: String, address: String) -> some View {
    SettingRow(title) {
      if let url = URL(string: address) {
        Link(destination: url) {
          Label(label, systemImage: "arrow.up.right")
            .labelStyle(TrailingIconLabelStyle())
        }
        .buttonStyle(ZenButtonStyle(kind: .text, size: .small))
        .padding(.trailing, -ZenSpacing.sm)
        .accessibilityLabel(title)
        .accessibilityValue(label)
      }
    }
  }
}

private struct TrailingIconLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: ZenSpacing.xxs) {
      configuration.title
      configuration.icon.font(ZenFont.iconSmall)
    }
  }
}
