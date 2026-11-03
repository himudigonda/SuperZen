import SwiftUI

struct ValidationNote: View {
  private let message: String

  init(_ message: String) {
    self.message = message
  }

  var body: some View {
    Label {
      Text(message)
        .font(ZenFont.bodySmall)
        .foregroundStyle(ZenColor.onWarningContainer)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(ZenColor.onWarningContainer)
    }
    .padding(.horizontal, ZenSpacing.md)
    .padding(.vertical, ZenSpacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(ZenColor.warningContainer, in: Rectangle())
    .accessibilityElement(children: .combine)
  }
}
