import SwiftUI

struct InsightsHeader: View {
  @ObservedObject var viewModel: InsightsViewModel
  let range: Binding<InsightsViewModel.Range>
  let onDeleteHistory: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: ZenSpacing.sm) {
      Text(updatedText)
        .font(ZenFont.bodySmall)
        .foregroundStyle(ZenColor.onSurfaceVariant)
        .contentTransition(.opacity)
      Spacer()
      ZenSegmentedPicker(
        String(localized: "Range", comment: "Insights range picker label"),
        selection: range,
        options: InsightsViewModel.Range.allCases,
        title: { $0.title }
      )
      .frame(width: 312)
      ZenMenu(
        items: [
          .action(String(localized: "Refresh Now", comment: "Insights menu item"), systemImage: "arrow.clockwise") {
            viewModel.refresh()
          },
          .divider(id: "refresh-divider"),
          .action(
            String(localized: "Delete All History...", comment: "Insights menu item"), systemImage: "trash",
            isEnabled: viewModel.hasStoredData, isDestructive: true
          ) {
            onDeleteHistory()
          },
        ],
        style: .icon
      ) {
        Image(systemName: "ellipsis.circle")
      }
      .fixedSize()
      .zenTooltip(String(localized: "More actions", comment: "Insights menu tooltip"))
      .accessibilityLabel(String(localized: "More actions", comment: "Insights menu tooltip"))
    }
  }

  private var updatedText: String {
    guard let updated = viewModel.lastUpdated else {
      return String(localized: "Loading your history", comment: "Insights header while loading")
    }
    return String(
      localized: "Updated \(InsightsFormat.clock(updated))", comment: "Insights header: last refresh time")
  }
}
