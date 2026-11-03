import SuperZenCore
import SwiftData
import SwiftUI

struct InsightsView: View {
  static let liveRefreshInterval: Duration = .seconds(60)
  static let bannerLifetime: Duration = .seconds(6)

  @Environment(\.modelContext) private var modelContext
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @StateObject private var viewModel = InsightsViewModel()
  @State private var confirmingClear = false
  @State private var rangeEdge: Edge = .trailing

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xl) {
      header
      if let outcome = viewModel.clearOutcome {
        clearBanner(outcome)
          .transition(ZenTransition.slide(insertion: .top, removal: .top, reduceMotion: reduceMotion))
      }
      if viewModel.isLoaded {
        content
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, minHeight: 240)
      }
    }
    .zenAnimation(.standard, value: viewModel.clearOutcome)
    .task {
      viewModel.load(context: modelContext)
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: Self.liveRefreshInterval)
        } catch {
          break
        }
        viewModel.refresh()
      }
    }
    .task(id: viewModel.clearOutcome) {
      guard viewModel.clearOutcome != nil else { return }
      do {
        try await Task.sleep(for: Self.bannerLifetime)
        viewModel.dismissClearOutcome()
      } catch {
        return
      }
    }
    .confirmationDialog(
      String(localized: "Delete all Insights history?", comment: "Insights clear data confirmation title"),
      isPresented: $confirmingClear,
      titleVisibility: .visible
    ) {
      Button(String(localized: "Delete All History", comment: "Insights clear data button"), role: .destructive) {
        viewModel.clearAllData()
      }
      Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) {}
    } message: {
      Text(
        "This permanently removes every focus session, break, wellness reminder and app usage record. Your settings stay as they are. This cannot be undone."
      )
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: ZenSpacing.sm) {
      VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
        Text("Insights")
          .font(ZenFont.title)
          .foregroundStyle(ZenColor.textPrimary)
          .accessibilityAddTraits(.isHeader)
        Text(updatedText)
          .font(ZenFont.caption)
          .foregroundStyle(ZenColor.textSecondary)
          .contentTransition(.opacity)
      }
      Spacer()
      Picker(String(localized: "Range", comment: "Insights range picker label"), selection: rangeBinding) {
        ForEach(InsightsViewModel.Range.allCases) { range in
          Text(range.title).tag(range)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 240)
      Menu {
        Button {
          viewModel.refresh()
        } label: {
          Label(String(localized: "Refresh Now", comment: "Insights menu item"), systemImage: "arrow.clockwise")
        }
        Divider()
        Button(role: .destructive) {
          confirmingClear = true
        } label: {
          Label(String(localized: "Delete All History...", comment: "Insights menu item"), systemImage: "trash")
        }
        .disabled(!viewModel.hasStoredData)
      } label: {
        Image(systemName: "ellipsis.circle")
          .font(ZenFont.bodyEmphasized)
          .foregroundStyle(ZenColor.accent)
      }
      .menuStyle(.button)
      .menuIndicator(.hidden)
      .buttonStyle(.plain)
      .fixedSize()
      .help(String(localized: "More actions", comment: "Insights menu tooltip"))
      .accessibilityLabel(String(localized: "More actions", comment: "Insights menu tooltip"))
    }
  }

  @ViewBuilder private var content: some View {
    if viewModel.loadFailed {
      Card {
        InsightsEmptyState(
          title: String(localized: "Insights could not load", comment: "Insights error title"),
          message: String(
            localized: "Your history is safe. Try Refresh Now from the menu.", comment: "Insights error message"),
          icon: "exclamationmark.triangle")
      }
    }

    VStack(alignment: .leading, spacing: ZenSpacing.xl) {
      kpiRow
      if let forecast = viewModel.forecastText {
        InsightsMessageCard(
          title: String(localized: "Forecast", comment: "Insights forecast card title"),
          message: forecast,
          icon: "calendar.badge.clock")
      }
      CardSection(
        String(localized: "Focus trend", comment: "Insights section title"),
        subtitle: viewModel.selectedRange.trendTitle
      ) {
        trendContent
          .padding(ZenSpacing.md)
          .id(viewModel.selectedRange)
          .transition(
            ZenTransition.slide(insertion: rangeEdge, removal: opposite(rangeEdge), reduceMotion: reduceMotion))
      }
    }
    .zenAnimation(.standard, value: viewModel.selectedRange)

    CardSection(
      String(localized: "Today's timeline", comment: "Insights section title"),
      subtitle: String(localized: "Focus, idle time and breaks through the day", comment: "Insights section subtitle")
    ) {
      timelineContent
        .padding(ZenSpacing.md)
    }

    CardSection(
      String(localized: "Weekly rhythm", comment: "Insights section title"),
      subtitle: String(localized: "Focus by hour over the last 7 days", comment: "Insights section subtitle")
    ) {
      heatmapContent
        .padding(ZenSpacing.md)
    }

    VStack(alignment: .leading, spacing: ZenSpacing.sm) {
      SectionHeader(
        String(localized: "Details", comment: "Insights section title"),
        subtitle: String(localized: "Sessions, interruptions and comparisons", comment: "Insights section subtitle"))
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: ZenSpacing.md, alignment: .top)], spacing: ZenSpacing.md) {
        ForEach(viewModel.details) { stat in
          StatTile(stat.title, value: stat.value, icon: stat.icon)
        }
      }
    }

    HStack(alignment: .top, spacing: ZenSpacing.md) {
      WellnessBreakdownCard(stats: viewModel.wellnessStats)
      appsContent
    }
  }

  private var kpiRow: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: ZenSpacing.md, alignment: .top)], spacing: ZenSpacing.md) {
      ForEach(viewModel.kpis) { kpi in
        StatTile(
          kpi.title, value: kpi.value, caption: kpi.caption, icon: kpi.icon, progress: kpi.progress,
          tint: tint(for: kpi.kind))
      }
    }
  }

  @ViewBuilder private var trendContent: some View {
    if viewModel.hasRangeData {
      InsightsTrendChart(
        points: viewModel.trend, range: viewModel.selectedRange, goalMinutes: viewModel.goalLineMinutes)
    } else {
      InsightsEmptyState(
        title: String(localized: "Nothing recorded yet", comment: "Insights empty trend title"),
        message: String(
          localized: "Focus time appears here as you work. Keep SuperZen running and check back after a session.",
          comment: "Insights empty trend message"),
        icon: "chart.bar")
    }
  }

  @ViewBuilder private var timelineContent: some View {
    if let domain = viewModel.timelineDomain, !viewModel.timelineBlocks.isEmpty {
      InsightsTimelineChart(blocks: viewModel.timelineBlocks, domain: domain, totals: viewModel.timelineTotals)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Today's timeline", comment: "Insights section title"))
        .accessibilityValue(viewModel.timelineSummary)
    } else {
      InsightsEmptyState(
        title: String(localized: "No activity today", comment: "Insights empty timeline title"),
        message: String(
          localized: "Your focus blocks, idle stretches and breaks will line up here.",
          comment: "Insights empty timeline message"),
        icon: "clock")
    }
  }

  @ViewBuilder private var heatmapContent: some View {
    if viewModel.hasHeatmapData {
      InsightsHeatmapChart(
        points: viewModel.heatmap, days: viewModel.heatmapDays, peakMinutes: viewModel.heatmapPeakMinutes,
        summary: viewModel.heatmapSummary)
    } else {
      InsightsEmptyState(
        title: String(localized: "No weekly pattern yet", comment: "Insights empty heatmap title"),
        message: String(
          localized: "After a few days you will see which hours you focus best.",
          comment: "Insights empty heatmap message"),
        icon: "square.grid.3x3")
    }
  }

  @ViewBuilder private var appsContent: some View {
    if viewModel.selectedRange == .today, let summary = viewModel.selectedWorkBlockSummary {
      VStack(alignment: .leading, spacing: ZenSpacing.sm) {
        if viewModel.workBlockAppSummaries.count > 1 {
          MenuPicker(
            String(localized: "Work block", comment: "Insights work block picker"),
            selection: workBlockBinding,
            catalog: viewModel.workBlockAppSummaries.map { ("\($0.label), \($0.timeWindow)", $0.id) })
        }
        WorkBlockAppsCard(summary: summary)
      }
    } else {
      TopAppsSummaryCard(
        title: String(localized: "Top apps during focus", comment: "Insights card title"),
        apps: viewModel.topAppsInRange)
    }
  }

  private var updatedText: String {
    guard let updated = viewModel.lastUpdated else {
      return String(localized: "Loading your history", comment: "Insights header while loading")
    }
    return String(
      localized: "Updated \(InsightsFormat.clock(updated))", comment: "Insights header: last refresh time")
  }

  private var rangeBinding: Binding<InsightsViewModel.Range> {
    Binding(
      get: { viewModel.selectedRange },
      set: { range in
        rangeEdge = range.order >= viewModel.selectedRange.order ? .trailing : .leading
        withZenAnimation(.standard, reduceMotion: reduceMotion) {
          viewModel.select(range)
        }
      })
  }

  private var workBlockBinding: Binding<UUID> {
    Binding(
      get: { viewModel.selectedWorkBlockSummary?.id ?? UUID() },
      set: { viewModel.selectWorkBlock($0) })
  }

  private func clearBanner(_ outcome: InsightsViewModel.ClearOutcome) -> some View {
    switch outcome {
    case .cleared(let records):
      return InsightsBanner(
        message: String(
          localized: "Deleted \(records) records. Insights start fresh from now.",
          comment: "Insights clear data success"),
        icon: "checkmark.circle.fill",
        tint: .success,
        onDismiss: { viewModel.dismissClearOutcome() })
    case .failed:
      return InsightsBanner(
        message: String(
          localized: "Could not delete your history. Nothing was removed.", comment: "Insights clear data failure"),
        icon: "exclamationmark.triangle.fill",
        tint: .danger,
        onDismiss: { viewModel.dismissClearOutcome() })
    }
  }

  private func tint(for kind: InsightsViewModel.KPIKind) -> ZenColor {
    switch kind {
    case .focus: return .accent
    case .breaks: return .success
    case .streak: return .warning
    case .quality: return .info
    }
  }

  private func opposite(_ edge: Edge) -> Edge {
    edge == .trailing ? .leading : .trailing
  }
}
