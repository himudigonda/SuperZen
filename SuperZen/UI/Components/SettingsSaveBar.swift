import SwiftUI

/// Bottom-aligned Save action shown on every settings screen that uses the draft-then-save
/// editing pattern: controls on the screen edit local `@State`, and nothing is written to
/// UserDefaults (so nothing can be silently overridden by another write) until this is tapped.
///
/// Saving is always available rather than gated behind a dirty check — tapping it when
/// nothing changed just re-persists the same values, which is harmless and keeps every
/// screen's save logic identical instead of each one hand-rolling change tracking.
struct SettingsSaveBar: View {
  let onSave: () -> Void
  @State private var justSaved = false
  /// Identifies which tap's hide-timer is still current, so a rapid second tap can't have its
  /// confirmation dismissed early by the first tap's now-stale timer.
  @State private var saveToken = UUID()

  var body: some View {
    HStack(spacing: 10) {
      Spacer()
      if justSaved {
        HStack(spacing: 6) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
          Text("Saved", comment: "Transient confirmation after tapping Save on a settings screen")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
        }
        .transition(.opacity)
      }
      Button(action: save) {
        Text("Save Changes", comment: "Button that persists a settings screen's edited values")
          .font(.system(size: 13, weight: .semibold))
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
      }
      .buttonStyle(.glassProminent)
      .tint(Theme.accent)
    }
    .padding(.top, 8)
    .animation(.easeInOut(duration: 0.2), value: justSaved)
  }

  private func save() {
    onSave()
    justSaved = true
    let token = UUID()
    saveToken = token
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      guard saveToken == token else { return }
      justSaved = false
    }
  }
}
