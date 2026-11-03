import SwiftUI

nonisolated struct ZenTooltipPresentation {
  let anchor: Anchor<CGRect>
  let text: String
}

nonisolated struct ZenTooltipPreferenceKey: PreferenceKey {
  static var defaultValue: ZenTooltipPresentation? { nil }
  static func reduce(value: inout ZenTooltipPresentation?, nextValue: () -> ZenTooltipPresentation?) {
    value = value ?? nextValue()
  }
}

struct ZenTooltipLayer: View {
  let presentation: ZenTooltipPresentation

  var body: some View {
    GeometryReader { proxy in
      ZenAnchoredLayout(anchor: proxy[presentation.anchor], placement: .tooltip, gap: ZenSpacing.xxs) {
        Text(presentation.text)
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.inverseOnSurface)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: 240)
          .padding(.horizontal, ZenSpacing.xs)
          .padding(.vertical, ZenSpacing.xxs)
          .background(ZenColor.inverseSurface, in: RoundedRectangle(cornerRadius: ZenRadius.xs, style: .continuous))
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private struct ZenTooltipModifier: ViewModifier {
  let text: String
  @State private var isVisible = false
  @State private var showTask: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .accessibilityHint(text)
      .onHover { hovering in
        showTask?.cancel()
        guard hovering, !text.isEmpty else {
          isVisible = false
          return
        }
        showTask = Task {
          try? await Task.sleep(for: .milliseconds(500))
          guard !Task.isCancelled else { return }
          isVisible = true
        }
      }
      .onDisappear {
        showTask?.cancel()
        isVisible = false
      }
      .background {
        Color.clear.anchorPreference(key: ZenTooltipPreferenceKey.self, value: .bounds) { anchor in
          isVisible ? ZenTooltipPresentation(anchor: anchor, text: text) : nil
        }
      }
  }
}

extension View {
  func zenTooltip(_ text: String) -> some View {
    modifier(ZenTooltipModifier(text: text))
  }
}
