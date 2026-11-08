import SwiftUI

struct InsightsMessageCard: View {
  let title: String
  let message: String
  let icon: String

  var body: some View {
    Card {
      HStack(spacing: ZenSpacing.md) {
        ZenListIcon(systemImage: icon)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(ZenFont.bodyMedium)
            .foregroundStyle(ZenColor.onSurface)
          Text(message)
            .font(ZenFont.bodySmall)
            .foregroundStyle(ZenColor.onSurfaceVariant)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, ZenSpacing.md)
      .padding(.vertical, ZenSpacing.xs)
      .frame(minHeight: 72)
    }
    .accessibilityElement(children: .combine)
  }
}

struct InsightsProgressRow: View {
  let title: String
  let detail: String
  let progress: Double

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
      HStack {
        Text(title)
          .font(ZenFont.labelMedium)
          .foregroundStyle(ZenColor.onSurface)
          .lineLimit(1)
        Spacer()
        Text(detail)
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
      }
      ZenLinearProgress(value: StatTile.clampedProgress(progress), tint: .primary)
    }
    .accessibilityElement(children: .combine)
  }
}

struct WellnessBreakdownCard: View {
  let stats: [InsightsViewModel.WellnessTypeStat]

  var body: some View {
    Card(padding: ZenSpacing.md, fillsHeight: true) {
      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        Label("Wellness completion by type", systemImage: "list.bullet.clipboard")
          .font(ZenFont.labelMedium)
          .foregroundStyle(ZenColor.onSurfaceVariant)
        ForEach(stats) { item in
          InsightsProgressRow(
            title: item.label,
            detail: "\(item.completed)/\(item.total) · \(item.completionRate)%",
            progress: Double(item.completionRate) / 100)
        }
      }
    }
  }
}

struct WorkBlockAppsCard: View {
  let summary: InsightsViewModel.WorkBlockAppSummary

  var body: some View {
    Card(padding: ZenSpacing.md, fillsHeight: true) {
      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: ZenSpacing.xxs / 2) {
            Text(summary.label)
              .font(ZenFont.labelMedium)
              .foregroundStyle(ZenColor.onSurface)
            Text(summary.timeWindow)
              .font(ZenFont.bodySmall)
              .foregroundStyle(ZenColor.onSurfaceVariant)
          }
          Spacer()
          Text(InsightsFormat.duration(Double(summary.totalMinutes) * 60))
            .font(ZenFont.labelMedium)
            .foregroundStyle(ZenColor.onSurfaceVariant)
        }
        ForEach(summary.rows) { row in
          InsightsProgressRow(
            title: row.appName,
            detail: "\(row.activeMinutes)m · \(row.activationCount)x",
            progress: row.share)
        }
        Text("\(summary.uniqueAppCount) unique apps in this block")
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
      }
    }
  }
}

struct TopAppsSummaryCard: View {
  let title: String
  let apps: [InsightsViewModel.TopAppSummary]

  var body: some View {
    Card(padding: ZenSpacing.md, fillsHeight: true) {
      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        Label(title, systemImage: "square.stack.3d.up")
          .font(ZenFont.labelMedium)
          .foregroundStyle(ZenColor.onSurfaceVariant)
        if apps.isEmpty {
          Text("Apps appear here when a focus block ends.")
            .font(ZenFont.bodySmall)
            .foregroundStyle(ZenColor.onSurfaceVariant)
        } else {
          ForEach(apps) { app in
            HStack {
              Text(app.appName)
                .font(ZenFont.labelMedium)
                .foregroundStyle(ZenColor.onSurface)
                .lineLimit(1)
              Spacer()
              Text(
                "\(InsightsFormat.duration(Double(app.activeMinutes) * 60)) · \(app.activationCount)×",
                comment: "Insights app row: focus time and how many times the app was opened"
              )
              .font(ZenFont.bodySmall)
              .foregroundStyle(ZenColor.onSurfaceVariant)
            }
            .accessibilityElement(children: .combine)
          }
        }
      }
    }
  }
}

struct InsightsEmptyState: View {
  let title: String
  let message: String
  let icon: String

  var body: some View {
    VStack(spacing: ZenSpacing.xs) {
      Image(systemName: icon)
        .font(ZenFont.iconMedium)
        .foregroundStyle(ZenColor.onSurfaceVariant)
        .accessibilityHidden(true)
      Text(title)
        .font(ZenFont.labelMedium)
        .foregroundStyle(ZenColor.onSurface)
      Text(message)
        .font(ZenFont.bodySmall)
        .foregroundStyle(ZenColor.onSurfaceVariant)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 88)
    .padding(.vertical, ZenSpacing.xs)
    .accessibilityElement(children: .combine)
  }
}

struct InsightsBanner: View {
  let message: String
  let icon: String
  let container: ZenColor
  let foreground: ZenColor
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: ZenSpacing.sm) {
      Image(systemName: icon)
        .foregroundStyle(foreground)
        .accessibilityHidden(true)
      Text(message)
        .font(ZenFont.bodySmall)
        .foregroundStyle(foreground)
      Spacer(minLength: ZenSpacing.xs)
      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .font(ZenFont.iconSmall)
          .foregroundStyle(foreground)
      }
      .buttonStyle(ZenIconButtonStyle(size: ZenSpacing.xxl))
      .accessibilityLabel(String(localized: "Dismiss", comment: "Insights banner dismiss button"))
    }
    .padding(.horizontal, ZenSpacing.md)
    .padding(.vertical, ZenSpacing.sm)
    .background(container, in: RoundedRectangle(cornerRadius: ZenRadius.md, style: .continuous))
    .accessibilityElement(children: .contain)
  }
}
