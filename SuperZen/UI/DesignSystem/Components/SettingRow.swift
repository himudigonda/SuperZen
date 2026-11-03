import SwiftUI

struct ZenListIcon: View {
  let systemImage: String

  var body: some View {
    Image(systemName: systemImage)
      .font(ZenFont.iconMedium)
      .foregroundStyle(ZenColor.onSecondaryContainer)
      .frame(width: 40, height: 40)
      .background(ZenColor.secondaryContainer, in: Circle())
      .accessibilityHidden(true)
  }
}

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
    HStack(alignment: .center, spacing: ZenSpacing.md) {
      if let icon {
        ZenListIcon(systemImage: icon)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(ZenFont.bodyMedium)
          .foregroundStyle(ZenColor.onSurface)
        if let subtitle {
          Text(subtitle)
            .font(ZenFont.bodySmall)
            .foregroundStyle(ZenColor.onSurfaceVariant)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: ZenSpacing.md)
      accessory
    }
    .padding(.horizontal, ZenSpacing.md)
    .padding(.vertical, ZenSpacing.xs)
    .frame(minHeight: subtitle == nil ? 56 : 72)
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
        .toggleStyle(.zenSwitch)
    }
  }
}
