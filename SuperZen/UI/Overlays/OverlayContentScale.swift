import SwiftUI

private struct OverlayContentScale: ViewModifier {
  func body(content: Content) -> some View {
    GeometryReader { proxy in
      content
        .scaleEffect(ZenOverlayMetrics.contentScale(for: proxy.size))
        .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }
}

extension View {
  func overlayContentScale() -> some View {
    modifier(OverlayContentScale())
  }
}
