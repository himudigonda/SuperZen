import SwiftUI

nonisolated struct ZenMenuItem: Identifiable {
  nonisolated enum Kind {
    case action
    case divider
  }

  let id: String
  let kind: Kind
  let title: String
  let systemImage: String?
  let isSelected: Bool
  let isEnabled: Bool
  let isDestructive: Bool
  let action: @MainActor () -> Void

  static func action(
    id: String? = nil,
    _ title: String,
    systemImage: String? = nil,
    isSelected: Bool = false,
    isEnabled: Bool = true,
    isDestructive: Bool = false,
    action: @escaping @MainActor () -> Void
  ) -> ZenMenuItem {
    ZenMenuItem(
      id: id ?? title, kind: .action, title: title, systemImage: systemImage, isSelected: isSelected,
      isEnabled: isEnabled, isDestructive: isDestructive, action: action)
  }

  static func divider(id: String) -> ZenMenuItem {
    ZenMenuItem(
      id: id, kind: .divider, title: "", systemImage: nil, isSelected: false, isEnabled: false, isDestructive: false,
      action: {})
  }
}

nonisolated enum ZenMenuNavigation {
  static func next(from current: String?, in items: [ZenMenuItem], forward: Bool) -> String? {
    let selectable = items.filter { $0.kind == .action && $0.isEnabled }
    guard !selectable.isEmpty else { return nil }
    guard let current, let index = selectable.firstIndex(where: { $0.id == current }) else {
      return (forward ? selectable.first : selectable.last)?.id
    }
    let offset = forward ? 1 : selectable.count - 1
    return selectable[(index + offset) % selectable.count].id
  }

  static func initial(in items: [ZenMenuItem]) -> String? {
    items.first { $0.kind == .action && $0.isSelected && $0.isEnabled }?.id
  }
}

nonisolated struct ZenMenuPresentation {
  let anchor: Anchor<CGRect>
  let items: [ZenMenuItem]
  let dismiss: @MainActor () -> Void
}

nonisolated struct ZenMenuPreferenceKey: PreferenceKey {
  static var defaultValue: ZenMenuPresentation? { nil }
  static func reduce(value: inout ZenMenuPresentation?, nextValue: () -> ZenMenuPresentation?) {
    value = value ?? nextValue()
  }
}

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

nonisolated struct ZenDialogPresentation {
  let content: AnyView
  let isDismissible: Bool
  let dismiss: @MainActor () -> Void
}

nonisolated struct ZenDialogPreferenceKey: PreferenceKey {
  static var defaultValue: ZenDialogPresentation? { nil }
  static func reduce(value: inout ZenDialogPresentation?, nextValue: () -> ZenDialogPresentation?) {
    value = value ?? nextValue()
  }
}

nonisolated enum ZenAnchorPlacement: Sendable {
  case menu
  case tooltip
}

nonisolated enum ZenAnchorGeometry {
  static let margin: CGFloat = 8

  static func origin(
    size: CGSize, anchor: CGRect, bounds: CGRect, placement: ZenAnchorPlacement, gap: CGFloat
  ) -> CGPoint {
    let minX = bounds.minX + margin
    let maxX = max(minX, bounds.maxX - margin - size.width)
    let minY = bounds.minY + margin
    let maxY = max(minY, bounds.maxY - margin - size.height)
    let preferredX: CGFloat
    switch placement {
    case .menu:
      preferredX = anchor.minX + size.width <= bounds.maxX - margin ? anchor.minX : anchor.maxX - size.width
    case .tooltip:
      preferredX = anchor.midX - size.width / 2
    }
    let below = anchor.maxY + gap
    let above = anchor.minY - gap - size.height
    let preferredY = below + size.height <= bounds.maxY - margin || above < minY ? below : above
    return CGPoint(x: min(maxX, max(minX, preferredX)), y: min(maxY, max(minY, preferredY)))
  }
}

private struct ZenAnchoredLayout: Layout {
  let anchor: CGRect
  let placement: ZenAnchorPlacement
  let gap: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    proposal.replacingUnspecifiedDimensions()
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard let subview = subviews.first else { return }
    let maxHeight = max(0, bounds.height - ZenAnchorGeometry.margin * 2)
    let maxWidth = max(0, bounds.width - ZenAnchorGeometry.margin * 2)
    let measured = subview.sizeThatFits(ProposedViewSize(width: nil, height: maxHeight))
    let size = CGSize(width: min(measured.width, maxWidth), height: min(measured.height, maxHeight))
    let origin = ZenAnchorGeometry.origin(
      size: size, anchor: anchor.offsetBy(dx: bounds.minX, dy: bounds.minY), bounds: bounds, placement: placement,
      gap: gap)
    subview.place(at: origin, anchor: .topLeading, proposal: ProposedViewSize(size))
  }
}

struct ZenMenu<Label: View>: View {
  private let items: [ZenMenuItem]
  private let label: Label
  private let style: ZenMenuTriggerStyle
  @State private var isOpen = false

  init(
    items: [ZenMenuItem],
    style: ZenMenuTriggerStyle = .plain,
    @ViewBuilder label: () -> Label
  ) {
    self.items = items
    self.style = style
    self.label = label()
  }

  var body: some View {
    trigger
      .anchorPreference(key: ZenMenuPreferenceKey.self, value: .bounds) { anchor in
        isOpen ? ZenMenuPresentation(anchor: anchor, items: items, dismiss: { isOpen = false }) : nil
      }
  }

  @ViewBuilder
  private var trigger: some View {
    let button = Button {
      isOpen.toggle()
    } label: {
      label
    }
    switch style {
    case .plain: button.buttonStyle(ZenMenuPlainTriggerStyle())
    case .icon: button.buttonStyle(.zenIcon)
    case .tonal: button.buttonStyle(ZenButtonStyle(kind: .tonal, size: .small))
    }
  }
}

nonisolated enum ZenMenuTriggerStyle: Sendable {
  case plain
  case icon
  case tonal
}

private struct ZenMenuPlainTriggerStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.contentShape(Rectangle())
  }
}

private struct ZenMenuLayer: View {
  let presentation: ZenMenuPresentation

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { presentation.dismiss() }
          .accessibilityHidden(true)
        ZenAnchoredLayout(anchor: proxy[presentation.anchor], placement: .menu, gap: ZenSpacing.xxs) {
          ZenMenuSurface(items: presentation.items, dismiss: presentation.dismiss)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        }
      }
    }
  }
}

private struct ZenMenuSurface: View {
  let items: [ZenMenuItem]
  let dismiss: @MainActor () -> Void
  @State private var highlighted: String?
  @FocusState private var isFocused: Bool

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.lg, style: .continuous)
    ViewThatFits(in: .vertical) {
      rows
      ScrollViewReader { reader in
        ScrollView {
          rows
        }
        .scrollIndicators(.automatic)
        .onAppear {
          if let selected = ZenMenuNavigation.initial(in: items) {
            reader.scrollTo(selected, anchor: .center)
          }
        }
        .onChange(of: highlighted) { _, target in
          if let target { reader.scrollTo(target) }
        }
      }
    }
    .frame(minWidth: 180, maxWidth: 360)
    .background(ZenColor.surfaceContainer, in: shape)
    .clipShape(shape)
    .zenElevation(.level2)
    .focusable()
    .focused($isFocused)
    .focusEffectDisabled()
    .onAppear {
      highlighted = ZenMenuNavigation.initial(in: items)
      isFocused = true
    }
    .onKeyPress(.upArrow) {
      highlighted = ZenMenuNavigation.next(from: highlighted, in: items, forward: false)
      return .handled
    }
    .onKeyPress(.downArrow) {
      highlighted = ZenMenuNavigation.next(from: highlighted, in: items, forward: true)
      return .handled
    }
    .onKeyPress(.return) {
      if let item = items.first(where: { $0.id == highlighted }), item.isEnabled { activate(item) }
      return .handled
    }
    .onKeyPress(.escape) {
      dismiss()
      return .handled
    }
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
    .accessibilityAction(.escape) { dismiss() }
  }

  private var rows: some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(items) { item in
        switch item.kind {
        case .divider:
          ZenDivider().padding(.vertical, ZenSpacing.xxs)
        case .action:
          ZenMenuRow(item: item, isHighlighted: highlighted == item.id) { activate(item) }
            .id(item.id)
        }
      }
    }
    .frame(minWidth: 172, alignment: .leading)
    .padding(ZenSpacing.xxs)
    .fixedSize(horizontal: true, vertical: true)
  }

  private func activate(_ item: ZenMenuItem) {
    dismiss()
    item.action()
  }
}

private struct ZenMenuRow: View {
  let item: ZenMenuItem
  let isHighlighted: Bool
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.md, style: .continuous)
    Button(action: action) {
      HStack(spacing: ZenSpacing.sm) {
        if let systemImage = item.systemImage {
          Image(systemName: systemImage)
            .font(ZenFont.iconMedium)
            .frame(width: ZenSpacing.xl)
            .accessibilityHidden(true)
        }
        Text(item.title)
          .font(ZenFont.labelLarge)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
        if item.isSelected {
          Image(systemName: "checkmark")
            .font(ZenFont.iconSmall)
            .accessibilityHidden(true)
        }
      }
      .foregroundStyle(foreground)
      .padding(.horizontal, ZenSpacing.sm)
      .frame(minHeight: 40)
      .background(item.isSelected ? AnyShapeStyle(ZenColor.secondaryContainer) : AnyShapeStyle(Color.clear), in: shape)
      .overlay(
        shape.fill(ZenColor.onSurface)
          .opacity(item.isEnabled && (isHovered || isHighlighted) ? ZenStateLayer.hover : 0)
          .allowsHitTesting(false)
      )
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .disabled(!item.isEnabled)
    .onHover { isHovered = $0 }
    .accessibilityAddTraits(item.isSelected ? .isSelected : [])
  }

  private var foreground: AnyShapeStyle {
    if !item.isEnabled { return AnyShapeStyle(ZenColor.onSurface.opacity(ZenStateLayer.disabledContent)) }
    if item.isDestructive { return AnyShapeStyle(ZenColor.error) }
    return item.isSelected ? AnyShapeStyle(ZenColor.onSecondaryContainer) : AnyShapeStyle(ZenColor.onSurface)
  }
}

private struct ZenTooltipLayer: View {
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

private struct ZenDialogLayer: View {
  let presentation: ZenDialogPresentation

  var body: some View {
    ZStack {
      Rectangle()
        .fill(ZenColor.scrim)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
          if presentation.isDismissible { presentation.dismiss() }
        }
        .accessibilityHidden(true)
        .transition(.opacity)
      presentation.content
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }
  }
}

struct ZenDialogSurface<Content: View, Actions: View>: View {
  let systemImage: String?
  let title: String
  let message: String?
  let width: CGFloat
  let content: Content
  let actions: Actions

  init(
    systemImage: String? = nil,
    title: String,
    message: String? = nil,
    width: CGFloat = 400,
    @ViewBuilder content: () -> Content,
    @ViewBuilder actions: () -> Actions
  ) {
    self.systemImage = systemImage
    self.title = title
    self.message = message
    self.width = width
    self.content = content()
    self.actions = actions()
  }

  var body: some View {
    VStack(alignment: systemImage == nil ? .leading : .center, spacing: ZenSpacing.md) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(ZenFont.iconLarge)
          .foregroundStyle(ZenColor.secondary)
          .accessibilityHidden(true)
      }
      Text(title)
        .font(ZenFont.headlineSmall)
        .foregroundStyle(ZenColor.onSurface)
        .multilineTextAlignment(systemImage == nil ? .leading : .center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      if let message {
        Text(message)
          .font(ZenFont.bodyMedium)
          .foregroundStyle(ZenColor.onSurfaceVariant)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      content
        .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: ZenSpacing.xs) {
        Spacer(minLength: 0)
        actions
      }
      .padding(.top, ZenSpacing.xs)
    }
    .padding(ZenSpacing.xl)
    .frame(width: width)
    .background(ZenColor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: ZenRadius.xl, style: .continuous))
    .zenElevation(.level3)
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
  }
}

private struct ZenDialogModifier<Dialog: View>: ViewModifier {
  @Binding var isPresented: Bool
  let isDismissible: Bool
  @ViewBuilder let dialog: () -> Dialog

  func body(content: Content) -> some View {
    content.background {
      Color.clear.preference(key: ZenDialogPreferenceKey.self, value: presentation)
    }
  }

  private var presentation: ZenDialogPresentation? {
    guard isPresented else { return nil }
    return ZenDialogPresentation(
      content: AnyView(
        dialog()
          .background {
            Button("") { if isDismissible { isPresented = false } }
              .keyboardShortcut(.cancelAction)
              .opacity(0)
              .accessibilityHidden(true)
          }
      ),
      isDismissible: isDismissible,
      dismiss: { isPresented = false })
  }
}

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

  func zenTooltip(_ text: String) -> some View {
    modifier(ZenTooltipModifier(text: text))
  }

  func zenDialog<Dialog: View>(
    isPresented: Binding<Bool>,
    isDismissible: Bool = true,
    @ViewBuilder dialog: @escaping () -> Dialog
  ) -> some View {
    modifier(ZenDialogModifier(isPresented: isPresented, isDismissible: isDismissible, dialog: dialog))
  }
}
