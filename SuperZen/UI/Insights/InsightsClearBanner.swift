import SwiftUI

struct InsightsClearBanner: View {
  let outcome: InsightsViewModel.ClearOutcome
  @ObservedObject var viewModel: InsightsViewModel

  var body: some View {
    switch outcome {
    case .cleared(let records):
      InsightsBanner(
        message: String(
          localized: "Deleted \(records) records. Insights start fresh from now.",
          comment: "Insights clear data success"),
        icon: "checkmark.circle.fill",
        container: .successContainer,
        foreground: .onSuccessContainer,
        onDismiss: { viewModel.dismissClearOutcome() })
    case .failed:
      InsightsBanner(
        message: String(
          localized: "Could not delete your history. Nothing was removed.", comment: "Insights clear data failure"),
        icon: "exclamationmark.triangle.fill",
        container: .errorContainer,
        foreground: .onErrorContainer,
        onDismiss: { viewModel.dismissClearOutcome() })
    }
  }
}
