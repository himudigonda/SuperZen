import SwiftUI

private struct ZenOverlayHost: ViewModifier {
  func body(content: Content) -> some View {
    content
      .overlayPreferenceValue(ZenDialogPreferenceKey.self) { presentation in
        ZStack {
          if let presentation {
            ZenDialogLayer(presentation: presentation)
          }
        }
        .zenAnimation(.standard, value: presentation != nil)
      }
      .overlayPreferenceValue(ZenMenuPreferenceKey.self) { presentation in
        ZStack {
          if let presentation {
            ZenMenuLayer(presentation: presentation)
          }
        }
        .zenAnimation(.quick, value: presentation != nil)
      }
      .overlayPreferenceValue(ZenTooltipPreferenceKey.self) { presentation in
        if let presentation {
          ZenTooltipLayer(presentation: presentation)
        }
      }
  }
}

extension View {
  func zenOverlayHost() -> some View {
    modifier(ZenOverlayHost())
  }
}
