import SwiftUI

struct SettingsSaveBar: View {
  let onSave: () -> Void
  @State private var justSaved = false
  @State private var saveToken = UUID()

  var body: some View {
    HStack(spacing: ZenSpacing.sm) {
      Spacer()
      if justSaved {
        Label {
          Text("Saved", comment: "Transient confirmation after tapping Save on a settings screen")
            .font(ZenFont.captionEmphasized)
            .foregroundStyle(ZenColor.textSecondary)
        } icon: {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(ZenColor.success)
        }
        .transition(.opacity)
      }
      Button(action: save) {
        Text("Save Changes", comment: "Button that persists a settings screen's edited values")
          .font(ZenFont.bodyEmphasized)
          .padding(.horizontal, ZenSpacing.md)
          .padding(.vertical, ZenSpacing.xs)
      }
      .buttonStyle(.glassProminent)
      .tint(ZenColor.accent)
    }
    .padding(.top, ZenSpacing.xs)
    .zenAnimation(.gentle, value: justSaved)
  }

  private func save() {
    onSave()
    justSaved = true
    let token = UUID()
    saveToken = token
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(2))
      guard saveToken == token else { return }
      justSaved = false
    }
  }
}
