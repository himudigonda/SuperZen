import Charts
import SuperZenCore
import SwiftUI

struct InsightsTrendChart: View {
  let points: [InsightsViewModel.TrendPoint]
  let range: InsightsViewModel.Range
  let goalMinutes: Double?

  @Environment(\.zenTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Chart {
      ForEach(points) { point in
        BarMark(
          x: .value("Time", point.date, unit: range.trendUnit),
          y: .value("Focus minutes", point.minutes)
        )
        .foregroundStyle(
          LinearGradient(
            colors: [color(.accent), color(.accentSecondary)], startPoint: .bottom, endPoint: .top)
        )
        .cornerRadius(ZenRadius.xs / 2)
        .accessibilityLabel(InsightsFormat.bucket(point.date, range: range))
        .accessibilityValue(InsightsFormat.duration(point.minutes * 60))
      }

      if let goalMinutes {
        RuleMark(y: .value("Goal", goalMinutes))
          .foregroundStyle(color(.warning))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
          .accessibilityLabel(String(localized: "Daily focus goal", comment: "Insights chart goal line"))
          .accessibilityValue(InsightsFormat.duration(goalMinutes * 60))
          .annotation(position: .top, alignment: .trailing) {
            Text("Goal \(InsightsFormat.duration(goalMinutes * 60))")
              .font(ZenFont.captionEmphasized)
              .foregroundStyle(ZenColor.textSecondary)
          }
      }
    }
    .chartXAxis {
      AxisMarks(values: .stride(by: range.trendUnit, count: axisStride)) { _ in
        AxisGridLine()
        AxisValueLabel(format: axisFormat)
      }
    }
    .chartYScale(domain: 0...yAxisUpperBound)
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine()
        AxisValueLabel {
          if let minutes = value.as(Double.self) { Text(InsightsFormat.duration(minutes * 60)) }
        }
      }
    }
    .frame(height: 220)
  }

  private var yAxisUpperBound: Double {
    max(10, points.map(\.minutes).max() ?? 0, (goalMinutes ?? 0) * 1.15)
  }

  private var axisStride: Int {
    switch range {
    case .today: return 3
    case .week: return 1
    case .month: return 5
    }
  }

  private var axisFormat: Date.FormatStyle {
    switch range {
    case .today: return .dateTime.hour()
    case .week: return .dateTime.weekday(.abbreviated)
    case .month: return .dateTime.month(.abbreviated).day()
    }
  }

  private func color(_ role: ZenColorRole) -> Color {
    theme.color(role, scheme: colorScheme)
  }
}

struct InsightsTimelineChart: View {
  let blocks: [InsightsViewModel.TimelineBlock]
  let domain: DateInterval
  let totals: [TimelineLane: TimeInterval]

  @Environment(\.zenTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.sm) {
      Chart(blocks) { block in
        BarMark(
          xStart: .value("Start", block.start),
          xEnd: .value("End", block.end),
          y: .value("Activity", block.lane.title),
          height: .ratio(0.7)
        )
        .foregroundStyle(laneColor(block.lane))
        .cornerRadius(ZenRadius.xs / 2)
        .accessibilityLabel(block.lane.title)
        .accessibilityValue(
          "\(InsightsFormat.clock(block.start)) to \(InsightsFormat.clock(block.end)), \(InsightsFormat.duration(block.duration))"
        )
      }
      .chartXScale(domain: domain.start...domain.end)
      .chartYScale(domain: TimelineLane.allCases.map(\.title))
      .chartYAxis {
        AxisMarks(preset: .aligned, position: .leading) { _ in
          AxisGridLine()
          AxisValueLabel(centered: true)
        }
      }
      .chartXAxis {
        AxisMarks(values: .stride(by: .hour, count: hourStride)) { _ in
          AxisGridLine()
          AxisValueLabel(format: .dateTime.hour())
        }
      }
      .frame(height: 132)

      HStack(spacing: ZenSpacing.md) {
        ForEach(TimelineLane.allCases, id: \.self) { lane in
          HStack(spacing: ZenSpacing.xxs) {
            Circle()
              .fill(laneColor(lane))
              .frame(width: ZenSpacing.xs, height: ZenSpacing.xs)
              .accessibilityHidden(true)
            Text("\(lane.title) \(InsightsFormat.duration(totals[lane] ?? 0))")
              .font(ZenFont.caption)
              .foregroundStyle(ZenColor.textSecondary)
              .monospacedDigit()
          }
        }
      }
    }
  }

  private var hourStride: Int {
    domain.duration > 10 * 3600 ? 3 : (domain.duration > 6 * 3600 ? 2 : 1)
  }

  private func laneColor(_ lane: TimelineLane) -> Color {
    switch lane {
    case .focus: return theme.color(.accent, scheme: colorScheme)
    case .idle: return theme.color(.textTertiary, scheme: colorScheme)
    case .rest: return theme.color(.success, scheme: colorScheme)
    }
  }
}

struct InsightsHeatmapChart: View {
  let points: [InsightsViewModel.HeatPoint]
  let days: [Date]
  let peakMinutes: Double
  let summary: String

  @Environment(\.zenTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  private static let cellInset = 0.06
  private static let axisHours = [0, 6, 12, 18, 24]

  var body: some View {
    Chart(points) { point in
      RectangleMark(
        xStart: .value("Hour", Double(point.hour) + Self.cellInset),
        xEnd: .value("Hour", Double(point.hour + 1) - Self.cellInset),
        y: .value("Day", InsightsFormat.weekday(point.day)),
        height: .ratio(0.84)
      )
      .foregroundStyle(fill(for: point.minutes))
      .cornerRadius(ZenRadius.xs / 2)
    }
    .chartXScale(domain: 0...Double(InsightsCalculator.hoursPerDay))
    .chartYScale(domain: days.map(InsightsFormat.weekday))
    .chartXAxis {
      AxisMarks(values: Self.axisHours.map { Double($0) }) { value in
        AxisValueLabel {
          if let hour = value.as(Double.self), let day = days.last {
            Text(InsightsFormat.hour(Int(hour) % InsightsCalculator.hoursPerDay, on: day))
          }
        }
      }
    }
    .chartYAxis {
      AxisMarks(preset: .aligned, position: .leading) { _ in AxisValueLabel(centered: true) }
    }
    .frame(height: 200)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(String(localized: "Focus by hour, last 7 days", comment: "Insights heatmap title"))
    .accessibilityValue(summary)
  }

  private func fill(for minutes: Double) -> Color {
    guard minutes > 0, peakMinutes > 0 else {
      return theme.color(.textTertiary, scheme: colorScheme).opacity(0.12)
    }
    let intensity = min(1, minutes / peakMinutes)
    return theme.color(.accent, scheme: colorScheme).opacity(0.25 + 0.75 * intensity)
  }
}
