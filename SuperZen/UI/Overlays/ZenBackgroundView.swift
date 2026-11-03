import AppKit
import SwiftUI

struct ZenBackgroundView: View {
  @AppStorage(SettingKey.breakBackground) var bgType = SettingsCatalog.breakBackgroundDefault
  @AppStorage(SettingKey.blurBackground) var useBlur = true
  @AppStorage(SettingKey.customImagePath) var customPath = ""

  var atmosphereColors: [Color]?

  var body: some View {
    ZStack {
      Rectangle().fill(ZenColor.surfaceContainerLowest).ignoresSafeArea()

      Group {
        if bgType == "Custom", let img = customImage {
          Image(nsImage: img)
            .resizable()
            .scaledToFill()
            .blur(radius: useBlur ? 40 : 0)
        } else if bgType == "Gradient" {
          if let colors = atmosphereColors {
            meshGradient(colors: colors)
          } else {
            ZenPalette.fallbackBackground
          }
        } else {
          ZStack {
            if useBlur {
              VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow)
                .blur(radius: 10)
            } else {
              VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                .brightness(-0.2)
            }
          }
        }
      }
      .ignoresSafeArea()
    }
    .environment(\.colorScheme, .dark)
  }

  private var customImage: NSImage? {
    guard !customPath.isEmpty else { return nil }
    return NSImage(contentsOfFile: customPath)
  }

  private func meshGradient(colors: [Color]) -> some View {
    MeshGradient(
      width: 3, height: 3,
      points: [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.5], [0.8, 0.2], [1, 0.5],
        [0, 1], [0.5, 1], [1, 1],
      ],
      colors: colors
    )
  }
}
