import SwiftUI

struct SkipPatternCard: View {
  let hour: Int?

  var body: some View {
    if let hour {
      InsightsMessageCard(
        title: String(
          localized: "You skip most breaks around \(InsightsFormat.hour(hour, on: Date()))",
          comment: "Insights skip pattern card title, argument is a clock hour such as 3 PM"),
        message: String(
          localized: "Try a planned break at that hour",
          comment: "Insights skip pattern card suggestion"),
        icon: "calendar.badge.clock")
    }
  }
}
