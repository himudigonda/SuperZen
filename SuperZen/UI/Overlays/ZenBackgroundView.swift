import AppKit
import SwiftUI

/// Shared full-screen background engine used by both Break and Wellness overlays.
/// Reads breakBackground / blurBackground / customImagePath from UserDefaults and
/// renders the correct layer based on the user's choice.
struct ZenBackgroundView: View {
  @AppStorage(SettingKey.breakBackground) var bgType = "Wallpaper"
  @AppStorage(SettingKey.blurBackground) var useBlur = true
  @AppStorage(SettingKey.customImagePath) var customPath = ""

  /// Atmosphere colors injected by the caller (break difficulty tints, wellness type tints).
  var atmosphereColors: [Color]?

  var body: some View {
    ZStack {
      // Base: always opaque black so gradients never bleed desktop content through
      Color.black.ignoresSafeArea()

      Group {
        if bgType == "Custom", let img = customImage {
          // Custom image — Gaussian blur applied at the image level for a dreamy look
          Image(nsImage: img)
            .resizable()
            .scaledToFill()
            .blur(radius: useBlur ? 40 : 0)
        } else if bgType == "Gradient" {
          // Fully opaque gradient — no desktop bleed-through
          if let colors = atmosphereColors {
            meshGradient(colors: colors)
          } else {
            Theme.gradientCasual
          }
        } else {
          // Wallpaper — sample the real macOS desktop through a vibrancy layer
          ZStack {
            if useBlur {
              VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow)
                .blur(radius: 10)
            } else {
              VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                .brightness(-0.2)
            }
            // Subtle atmosphere tint on top of the wallpaper
            if let colors = atmosphereColors {
              meshGradient(colors: colors).opacity(0.01)
            }
          }
        }
      }
      .ignoresSafeArea()
    }
  }

  // MARK: - Helpers

  private var customImage: NSImage? {
    guard !customPath.isEmpty else { return nil }
    return NSImage(contentsOfFile: customPath)
  }

  @ViewBuilder
  private func meshGradient(colors: [Color]) -> some View {
    if #available(macOS 15.0, *) {
      MeshGradient(
        width: 3, height: 3,
        points: [
          [0, 0], [0.5, 0], [1, 0],
          [0, 0.5], [0.8, 0.2], [1, 0.5],
          [0, 1], [0.5, 1], [1, 1],
        ],
        colors: colors
      )
    } else {
      LinearGradient(
        colors: [colors[1], colors[4], .black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }
}
