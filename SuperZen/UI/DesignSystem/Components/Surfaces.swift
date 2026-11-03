import SwiftUI

private struct ZenSurfaceModifier: ViewModifier {
  let cornerRadius: CGFloat
  let elevation: ZenElevation
  let isSelected: Bool

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    content
      .background {
        shape.fill(ZenGradient.surface).zenElevation(elevation)
      }
      .overlay {
        shape.strokeBorder(
          isSelected ? AnyShapeStyle(ZenColor.accent) : AnyShapeStyle(ZenColor.surfaceStroke),
          lineWidth: isSelected ? 2 : 1
        )
      }
  }
}

extension View {
  func zenSurface(
    cornerRadius: CGFloat = ZenRadius.lg,
    elevation: ZenElevation = .raised,
    isSelected: Bool = false
  ) -> some View {
    modifier(
      ZenSurfaceModifier(cornerRadius: cornerRadius, elevation: elevation, isSelected: isSelected))
  }
}

struct Card<Content: View>: View {
  private let padding: CGFloat
  private let elevation: ZenElevation
  private let content: Content

  init(
    padding: CGFloat = 0,
    elevation: ZenElevation = .raised,
    @ViewBuilder content: () -> Content
  ) {
    self.padding = padding
    self.elevation = elevation
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .padding(padding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .zenSurface(elevation: elevation)
  }
}

struct ZenHairline: View {
  var body: some View {
    Rectangle()
      .fill(ZenColor.divider)
      .frame(height: 1)
      .accessibilityHidden(true)
  }
}

struct CardDivider: View {
  var body: some View {
    ZenHairline()
      .padding(.horizontal, ZenSpacing.md)
  }
}

struct SectionHeader: View {
  private let title: Text
  private let subtitle: Text?

  init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
    self.title = Text(title)
    self.subtitle = subtitle.map { Text($0) }
  }

  @_disfavoredOverload
  init(_ title: String, subtitle: String? = nil) {
    self.title = Text(verbatim: title)
    self.subtitle = subtitle.map { Text(verbatim: $0) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxs / 2) {
      title
        .font(ZenFont.headline)
        .foregroundStyle(ZenColor.textPrimary)
        .accessibilityAddTraits(.isHeader)
      if let subtitle {
        subtitle
          .font(ZenFont.subheadline)
          .foregroundStyle(ZenColor.textSecondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct CardSection<Content: View>: View {
  private let header: SectionHeader
  private let content: Content

  init(
    _ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.header = SectionHeader(title, subtitle: subtitle)
    self.content = content()
  }

  @_disfavoredOverload
  init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
    self.header = SectionHeader(title, subtitle: subtitle)
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.sm) {
      header
      Card { content }
    }
  }
}

struct VisualEffectBlur: NSViewRepresentable {
  var material: NSVisualEffectView.Material
  var blendingMode: NSVisualEffectView.BlendingMode
  var state: NSVisualEffectView.State = .active

  func makeNSView(context _: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = state
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
    nsView.state = state
  }
}

struct ZenCanvasBackground: View {
  @Environment(\.zenTheme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let isDark = colorScheme == .dark
    ZStack {
      Rectangle().fill(ZenColor.canvas)
      LinearGradient(
        colors: [color(.canvasGlowTop), color(.canvasGlowBottom)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      glow(.accent, opacity: isDark ? 0.2 : 0.1, center: UnitPoint(x: -0.1, y: -0.2))
      glow(.accentSecondary, opacity: isDark ? 0.1 : 0.06, center: UnitPoint(x: 1.1, y: -0.2))
      glow(.accentTertiary, opacity: isDark ? 0.07 : 0.04, center: UnitPoint(x: -0.1, y: 1.2))
    }
    .ignoresSafeArea()
  }

  private func color(_ role: ZenColorRole) -> Color {
    theme.color(role, scheme: colorScheme)
  }

  private func glow(_ role: ZenColorRole, opacity: Double, center: UnitPoint) -> EllipticalGradient {
    EllipticalGradient(
      colors: [theme.rgba(role, scheme: colorScheme).withAlpha(opacity).color, .clear],
      center: center,
      startRadiusFraction: 0,
      endRadiusFraction: 0.9
    )
  }
}

struct ZenSidebarBackground: View {
  var body: some View {
    Rectangle()
      .fill(.ultraThinMaterial)
      .overlay(ZenGradient(roles: [.canvasGlowTop, .surfaceBottom]).opacity(0.4))
      .overlay(alignment: .trailing) {
        Rectangle()
          .fill(ZenColor.surfaceStroke)
          .frame(width: 1)
      }
  }
}
