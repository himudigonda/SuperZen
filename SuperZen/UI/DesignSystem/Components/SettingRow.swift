import SwiftUI

struct SettingRow<Accessory: View>: View {
  private let title: String
  private let subtitle: String?
  private let icon: String?
  private let accessory: Accessory

  init(
    _ title: String,
    subtitle: String? = nil,
    icon: String? = nil,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.title = title
    self.subtitle = subtitle
    self.icon = icon
    self.accessory = accessory()
  }

  var body: some View {
    HStack(alignment: .center, spacing: ZenSpacing.sm) {
      if let icon {
        Image(systemName: icon)
          .font(ZenFont.rowIcon)
          .foregroundStyle(ZenColor.textSecondary)
          .frame(width: ZenSpacing.xl)
          .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
        Text(title)
          .font(ZenFont.body)
          .foregroundStyle(ZenColor.textPrimary)
        if let subtitle {
          Text(subtitle)
            .font(ZenFont.subheadline)
            .foregroundStyle(ZenColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: ZenSpacing.md)
      accessory
    }
    .padding(.horizontal, ZenSpacing.md)
    .padding(.vertical, ZenSpacing.sm)
    .accessibilityElement(children: .contain)
  }
}

extension SettingRow where Accessory == EmptyView {
  init(_ title: String, subtitle: String? = nil, icon: String? = nil) {
    self.init(title, subtitle: subtitle, icon: icon) { EmptyView() }
  }
}

struct LabeledToggle: View {
  private let title: String
  private let subtitle: String?
  private let icon: String?
  @Binding private var isOn: Bool

  init(_ title: String, subtitle: String? = nil, icon: String? = nil, isOn: Binding<Bool>) {
    self.title = title
    self.subtitle = subtitle
    self.icon = icon
    self._isOn = isOn
  }

  var body: some View {
    SettingRow(title, subtitle: subtitle, icon: icon) {
      Toggle(title, isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .tint(ZenColor.accent)
    }
  }
}
