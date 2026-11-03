import SwiftUI

nonisolated enum ZenCardKind: Sendable {
  case filled
  case elevated
  case outlined
}

private struct ZenSurfaceModifier: ViewModifier {
  let cornerRadius: CGFloat
  let elevation: ZenElevation
  let isSelected: Bool
  let kind: ZenCardKind

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    content
      .background(fill, in: shape)
      .overlay {
        if isSelected {
          shape.strokeBorder(ZenColor.primary, lineWidth: 2)
        } else if kind == .outlined {
          shape.strokeBorder(ZenColor.outlineVariant, lineWidth: 1)
        }
      }
      .zenElevation(kind == .elevated && elevation == .level0 ? .level1 : elevation)
  }

  private var fill: AnyShapeStyle {
    if isSelected { return AnyShapeStyle(ZenColor.secondaryContainer) }
    switch kind {
    case .filled: return AnyShapeStyle(ZenColor.surfaceContainer)
    case .elevated: return AnyShapeStyle(ZenColor.surfaceContainerLow)
    case .outlined: return AnyShapeStyle(ZenColor.surface)
    }
  }
}

extension View {
  func zenSurface(
    cornerRadius: CGFloat = ZenRadius.lg,
    elevation: ZenElevation = .level0,
    isSelected: Bool = false,
    kind: ZenCardKind = .filled
  ) -> some View {
    modifier(
      ZenSurfaceModifier(cornerRadius: cornerRadius, elevation: elevation, isSelected: isSelected, kind: kind))
  }
}

struct Card<Content: View>: View {
  private let padding: CGFloat
  private let kind: ZenCardKind
  private let fillsHeight: Bool
  private let content: Content

  init(
    padding: CGFloat = 0,
    kind: ZenCardKind = .filled,
    fillsHeight: Bool = false,
    @ViewBuilder content: () -> Content
  ) {
    self.padding = padding
    self.kind = kind
    self.fillsHeight = fillsHeight
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .padding(padding)
    .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
    .zenSurface(kind: kind)
    .clipShape(RoundedRectangle(cornerRadius: ZenRadius.lg, style: .continuous))
  }
}

struct CardDivider: View {
  var body: some View {
    Rectangle()
      .fill(ZenColor.surface)
      .frame(height: 2)
      .accessibilityHidden(true)
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
    VStack(alignment: .leading, spacing: ZenSpacing.xxs) {
      title
        .font(ZenFont.titleSmall)
        .foregroundStyle(ZenColor.primary)
        .accessibilityAddTraits(.isHeader)
      if let subtitle {
        subtitle
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, ZenSpacing.xxs)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SettingsPage<Content: View>: View {
  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.xxl) {
      content
    }
  }
}

struct PageSection<Content: View>: View {
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
    VStack(alignment: .leading, spacing: ZenSpacing.xs) {
      header
      content
    }
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
    VStack(alignment: .leading, spacing: ZenSpacing.xs) {
      header
      Card { content }
    }
  }
}

struct ZenCanvasBackground: View {
  var body: some View {
    Rectangle()
      .fill(ZenColor.surface)
      .ignoresSafeArea()
  }
}

struct ZenSidebarBackground: View {
  var body: some View {
    Rectangle()
      .fill(ZenColor.surfaceContainerLow)
      .ignoresSafeArea()
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
