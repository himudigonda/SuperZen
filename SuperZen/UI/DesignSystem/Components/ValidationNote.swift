import SwiftUI

struct ValidationNote: View {
  private let message: String

  init(_ message: String) {
    self.message = message
  }

  var body: some View {
    Label {
      Text(message)
        .font(ZenFont.subheadline)
        .foregroundStyle(ZenColor.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(ZenColor.warning)
    }
    .padding(.horizontal, ZenSpacing.md)
    .padding(.vertical, ZenSpacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}
