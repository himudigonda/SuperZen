import SwiftUI

struct AboutView: View {
  private let appVersion =
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
  private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "15"

  var body: some View {
    VStack(spacing: ZenSpacing.xxl) {
      Spacer().frame(height: ZenSpacing.lg)

      ZStack {
        Circle()
          .fill(ZenGradient.accent)
          .frame(width: 100, height: 100)
          .zenElevation(.floating)
        Image(systemName: "eye.fill")
          .font(ZenFont.heroIcon)
          .foregroundStyle(ZenColor.onAccent)
      }
      .accessibilityHidden(true)

      VStack(spacing: ZenSpacing.xs) {
        Text(verbatim: "SuperZen")
          .font(ZenFont.title)
          .foregroundStyle(ZenColor.textPrimary)
          .accessibilityAddTraits(.isHeader)
        Text("by Himansh Mudigonda (@himudigonda)")
          .font(ZenFont.body)
          .foregroundStyle(ZenColor.textSecondary)
        Text("Version \(appVersion) (\(buildNumber))")
          .font(ZenFont.body)
          .foregroundStyle(ZenColor.textSecondary)
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
        SettingRow(
          String(localized: "Support", comment: "About screen row title: support contact")
        ) {
          Text(verbatim: "himudigonda@gmail.com")
            .font(ZenFont.body)
            .foregroundStyle(ZenColor.textSecondary)
            .textSelection(.enabled)
        }
      }

      Spacer()

      Text("Please take care of yourself ❤️")
        .font(ZenFont.subheadline)
        .foregroundStyle(ZenColor.textSecondary)
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
            .font(ZenFont.body)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ZenColor.accent)
      }
    }
  }
}

private struct TrailingIconLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: ZenSpacing.xxs) {
      configuration.title
      configuration.icon.font(ZenFont.controlIcon)
    }
  }
}
