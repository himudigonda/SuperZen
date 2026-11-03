import AppKit
import SwiftUI

struct ZenTopAppBar<Actions: View>: View {
  let title: String
  let isScrolled: Bool
  let actions: Actions

  init(_ title: String, isScrolled: Bool = false, @ViewBuilder actions: () -> Actions) {
    self.title = title
    self.isScrolled = isScrolled
    self.actions = actions()
  }

  var body: some View {
    HStack(spacing: ZenSpacing.xs) {
      Text(title)
        .font(ZenFont.titleLarge)
        .foregroundStyle(ZenColor.onSurface)
        .lineLimit(1)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: ZenSpacing.md)
      actions
    }
    .padding(.horizontal, ZenSpacing.xl)
    .frame(height: 64)
    .frame(maxWidth: .infinity)
    .background(isScrolled ? ZenColor.surfaceContainer : ZenColor.surface)
    .contentShape(Rectangle())
    .gesture(WindowDragGesture())
    .simultaneousGesture(
      TapGesture(count: 2).onEnded { NSApp.keyWindow?.performZoom(nil) }
    )
    .zenAnimation(.standard, value: isScrolled)
  }
}

extension ZenTopAppBar where Actions == EmptyView {
  init(_ title: String, isScrolled: Bool = false) {
    self.init(title, isScrolled: isScrolled) { EmptyView() }
  }
}

struct ZenDrawerItem: View {
  let title: String
  let systemImage: String
  let isSelected: Bool
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: ZenSpacing.sm) {
        Image(systemName: systemImage)
          .symbolVariant(isSelected ? .fill : .none)
          .font(ZenFont.iconMedium)
          .frame(width: ZenSpacing.xl)
          .accessibilityHidden(true)
        Text(title)
          .font(isSelected ? ZenFont.titleSmall : ZenFont.bodyMedium)
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .foregroundStyle(isSelected ? ZenColor.onSecondaryContainer : ZenColor.onSurfaceVariant)
      .padding(.horizontal, ZenSpacing.md)
      .frame(height: 44)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        isSelected ? AnyShapeStyle(ZenColor.secondaryContainer) : AnyShapeStyle(Color.clear),
        in: Capsule(style: .circular)
      )
      .overlay(
        Capsule(style: .circular).fill(ZenColor.onSurface).opacity(isHovered ? ZenStateLayer.hover : 0)
          .allowsHitTesting(false)
      )
      .zenFocusRing(Capsule(style: .circular))
      .contentShape(Capsule(style: .circular))
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .onHover { isHovered = $0 }
    .zenAnimation(.quick, value: isHovered)
    .zenAnimation(.emphasized, value: isSelected)
    .accessibilityLabel(title)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

struct ZenRailItem: View {
  let title: String
  let systemImage: String
  let isSelected: Bool
  let action: () -> Void
  @State private var isHovered = false

  private var isSingleWord: Bool {
    !title.contains { $0.isWhitespace || $0 == "-" }
  }

  var body: some View {
    Button(action: action) {
      VStack(spacing: ZenSpacing.xxs) {
        Image(systemName: systemImage)
          .symbolVariant(isSelected ? .fill : .none)
          .font(ZenFont.iconMedium)
          .foregroundStyle(isSelected ? ZenColor.onSecondaryContainer : ZenColor.onSurfaceVariant)
          .frame(width: 56, height: 32)
          .background(
            isSelected ? AnyShapeStyle(ZenColor.secondaryContainer) : AnyShapeStyle(Color.clear),
            in: Capsule(style: .circular)
          )
          .overlay(
            Capsule(style: .circular).fill(ZenColor.onSurface).opacity(isHovered ? ZenStateLayer.hover : 0)
              .allowsHitTesting(false)
          )
          .zenFocusRing(Capsule(style: .circular))
          .accessibilityHidden(true)
        Text(title)
          .font(ZenFont.labelSmall)
          .foregroundStyle(isSelected ? ZenColor.onSurface : ZenColor.onSurfaceVariant)
          .lineLimit(isSingleWord ? 1 : 2)
          .minimumScaleFactor(0.75)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .onHover { isHovered = $0 }
    .zenAnimation(.quick, value: isHovered)
    .zenAnimation(.emphasized, value: isSelected)
    .accessibilityLabel(title)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
