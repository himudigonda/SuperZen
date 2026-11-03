import AppKit
import SwiftUI

private struct OverlayBackdropBlur: NSViewRepresentable {
  let material: NSVisualEffectView.Material

  func makeNSView(context _: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.blendingMode = .behindWindow
    view.state = .active
    view.appearance = NSAppearance(named: .darkAqua)
    view.material = material
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context _: Context) {
    view.material = material
  }
}

struct ZenBackgroundView: View {
  @AppStorage(SettingKey.breakBackground) var bgType = SettingsCatalog.breakBackgroundDefault
  @AppStorage(SettingKey.blurBackground) var useBlur = true
  @AppStorage(SettingKey.customImagePath) var customPath = ""
  @Environment(\.zenTheme) private var theme
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var atmosphereColors: [Color]?

  static func isCustomImageMissing(type: String, path: String) -> Bool {
    type == "Custom" && !FileManager.default.isReadableFile(atPath: path)
  }

  var body: some View {
    ZStack {
      Rectangle().fill(ZenColor.surfaceContainerLowest)
      backdrop
      scrim
    }
    .ignoresSafeArea()
    .environment(\.colorScheme, .dark)
    .accessibilityHidden(true)
  }

  private var backdropKind: ZenScrimBackdrop {
    bgType == "Gradient" ? .atmosphere : .photograph
  }

  private var scrimColor: Color {
    theme.color(backdropKind.role(highContrast: theme.contrast == .high), scheme: .dark)
  }

  private var poolColor: Color {
    theme.color(.overlayPool, scheme: .dark)
  }

  @ViewBuilder
  private var backdrop: some View {
    if bgType == "Custom", let image = customImage {
      GeometryReader { proxy in
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: proxy.size.width, height: proxy.size.height)
          .blur(radius: useBlur ? 40 : 0)
          .scaleEffect(useBlur ? 1.12 : 1)
          .clipped()
      }
    } else if bgType == "Gradient" {
      if let colors = atmosphereColors {
        meshGradient(colors: colors)
      } else {
        Rectangle().fill(ZenPalette.fallbackBackground)
      }
    } else if reduceTransparency {
      Rectangle().fill(ZenColor.surfaceContainerLowest)
    } else {
      OverlayBackdropBlur(material: useBlur ? .fullScreenUI : .underWindowBackground)
    }
  }

  private var scrim: some View {
    ZStack {
      Rectangle().fill(scrimColor)
      Rectangle().fill(
        RadialGradient(
          colors: [poolColor, poolColor.opacity(0)],
          center: .center, startRadius: 0, endRadius: 760))
    }
    .allowsHitTesting(false)
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
