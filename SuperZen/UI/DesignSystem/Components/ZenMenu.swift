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

struct ZenMenu<Label: View>: View {
  private let items: [ZenMenuItem]
  private let label: Label
  private let style: ZenMenuTriggerStyle
  @State private var isOpen = false
  @FocusState private var isTriggerFocused: Bool

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
      .focused($isTriggerFocused)
      .anchorPreference(key: ZenMenuPreferenceKey.self, value: .bounds) { anchor in
        isOpen ? ZenMenuPresentation(anchor: anchor, items: items, dismiss: close) : nil
      }
  }

  private func close() {
    isOpen = false
    isTriggerFocused = true
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
    configuration.label.contentShape(Rectangle()).focusEffectDisabled()
  }
}

struct ZenMenuLayer: View {
  let presentation: ZenMenuPresentation

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        Button(action: presentation.dismiss) {
          Color.clear.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
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
