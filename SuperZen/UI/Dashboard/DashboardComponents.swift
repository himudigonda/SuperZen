import SwiftUI

struct DashboardMessageCard: View {
  let title: String
  let message: String
  let icon: String

  var body: some View {
    Card(padding: ZenSpacing.md) {
      VStack(alignment: .leading, spacing: ZenSpacing.xs) {
        Label(title, systemImage: icon)
          .font(ZenFont.captionEmphasized)
          .foregroundStyle(ZenColor.textSecondary)
        Text(message)
          .font(ZenFont.subheadlineEmphasized)
          .foregroundStyle(ZenColor.textPrimary)
          .lineSpacing(ZenSpacing.xxs / 2)
      }
      .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
    }
    .accessibilityElement(children: .combine)
  }
}

struct DashboardProgressRow: View {
  let title: String
  let detail: String
  let progress: Double

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
      HStack {
        Text(title)
          .font(ZenFont.captionEmphasized)
          .foregroundStyle(ZenColor.textPrimary)
          .lineLimit(1)
        Spacer()
        Text(detail)
          .font(ZenFont.caption)
          .foregroundStyle(ZenColor.textSecondary)
      }
      ProgressView(value: StatTile.clampedProgress(progress))
        .tint(ZenColor.accent)
    }
    .accessibilityElement(children: .combine)
  }
}

struct WellnessBreakdownCard: View {
  let stats: [DashboardViewModel.WellnessTypeStat]

  var body: some View {
    Card(padding: ZenSpacing.md) {
      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        Label("Wellness completion by type", systemImage: "list.bullet.clipboard")
          .font(ZenFont.captionEmphasized)
          .foregroundStyle(ZenColor.textSecondary)
        ForEach(stats) { item in
          DashboardProgressRow(
            title: item.label,
            detail: "\(item.completed)/\(item.total) · \(item.completionRate)%",
            progress: Double(item.completionRate) / 100)
        }
      }
    }
  }
}

struct WorkBlockAppsCard: View {
  let summary: DashboardViewModel.WorkBlockAppSummary

  var body: some View {
    Card(padding: ZenSpacing.md) {
      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: ZenSpacing.xxs / 2) {
            Text(summary.label)
              .font(ZenFont.subheadlineEmphasized)
              .foregroundStyle(ZenColor.textPrimary)
            Text(summary.timeWindow)
              .font(ZenFont.caption)
              .foregroundStyle(ZenColor.textSecondary)
          }
          Spacer()
          Text("\(summary.totalMinutes)m")
            .font(ZenFont.captionEmphasized)
            .foregroundStyle(ZenColor.textSecondary)
        }
        ForEach(summary.rows) { row in
          DashboardProgressRow(
            title: row.appName,
            detail: "\(row.activeMinutes)m · \(row.activationCount)x",
            progress: row.share)
        }
        Text("\(summary.uniqueAppCount) unique apps in this block")
          .font(ZenFont.caption)
          .foregroundStyle(ZenColor.textSecondary)
      }
    }
  }
}

struct TopAppsSummaryCard: View {
  let title: String
  let apps: [DashboardViewModel.TopAppSummary]

  var body: some View {
    Card(padding: ZenSpacing.md) {
      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        Label(title, systemImage: "square.stack.3d.up")
          .font(ZenFont.captionEmphasized)
          .foregroundStyle(ZenColor.textSecondary)
        if apps.isEmpty {
          Text("No app activity recorded yet in this range.")
            .font(ZenFont.caption)
            .foregroundStyle(ZenColor.textSecondary)
        } else {
          ForEach(apps) { app in
            HStack {
              Text(app.appName)
                .font(ZenFont.captionEmphasized)
                .foregroundStyle(ZenColor.textPrimary)
                .lineLimit(1)
              Spacer()
              Text("\(app.activeMinutes)m · \(app.activationCount)x")
                .font(ZenFont.caption)
                .foregroundStyle(ZenColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
          }
        }
      }
    }
  }
}
