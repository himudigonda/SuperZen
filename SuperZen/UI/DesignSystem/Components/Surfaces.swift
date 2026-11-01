import SwiftUI

private struct ZenSurfaceModifier: ViewModifier {
  let cornerRadius: CGFloat
  let elevation: ZenElevation
  let isSelected: Bool

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    content
      .background {
        shape.fill(.thinMaterial)
        shape.fill(ZenGradient.surface)
      }
      .overlay {
        shape.strokeBorder(
          isSelected ? AnyShapeStyle(ZenColor.accent) : AnyShapeStyle(ZenColor.surfaceStroke),
          lineWidth: isSelected ? 2 : 1
        )
      }
      .zenElevation(elevation)
      .glassEffect(.regular, in: shape)
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

struct CardDivider: View {
  var body: some View {
    Divider()
      .overlay(ZenColor.divider)
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
      glow(.accent, opacity: isDark ? 0.25 : 0.12, center: .topLeading, endRadius: 620)
        .offset(x: -120, y: -170)
      glow(.accentSecondary, opacity: isDark ? 0.18 : 0.08, center: .topTrailing, endRadius: 560)
        .offset(x: 110, y: -160)
      glow(.accentTertiary, opacity: isDark ? 0.12 : 0.06, center: .bottomLeading, endRadius: 760)
        .offset(x: -90, y: 240)
    }
    .ignoresSafeArea()
  }

  private func color(_ role: ZenColorRole) -> Color {
    theme.color(role, scheme: colorScheme)
  }

  private func glow(
    _ role: ZenColorRole, opacity: Double, center: UnitPoint, endRadius: CGFloat
  ) -> RadialGradient {
    RadialGradient(
      colors: [theme.rgba(role, scheme: colorScheme).withAlpha(opacity).color, .clear],
      center: center,
      startRadius: 30,
      endRadius: endRadius
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
