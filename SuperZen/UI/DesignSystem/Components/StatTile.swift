import SwiftUI

struct StatTile: View {
  private let title: String
  private let value: String
  private let icon: String?
  private let caption: String?
  private let progress: Double?
  private let tint: ZenColor

  init(
    _ title: String,
    value: String,
    caption: String? = nil,
    icon: String? = nil,
    progress: Double? = nil,
    tint: ZenColor = .accent
  ) {
    self.title = title
    self.value = value
    self.icon = icon
    self.caption = caption
    self.progress = progress.map(Self.clampedProgress)
    self.tint = tint
  }

  static func clampedProgress(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xs) {
      titleLabel
        .font(ZenFont.captionEmphasized)
        .foregroundStyle(ZenColor.textSecondary)
      Text(value)
        .font(ZenFont.statValue)
        .foregroundStyle(ZenColor.textPrimary)
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      if let progress {
        ProgressView(value: progress)
          .tint(tint)
      }
      if let caption {
        Text(caption)
          .font(ZenFont.caption)
          .foregroundStyle(ZenColor.textSecondary)
      }
    }
    .padding(ZenSpacing.md)
    .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
    .zenSurface()
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private var titleLabel: some View {
    if let icon {
      Label(title, systemImage: icon)
    } else {
      Text(title)
    }
  }
}
