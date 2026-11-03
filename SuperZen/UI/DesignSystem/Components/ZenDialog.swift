import SwiftUI

nonisolated struct ZenDialogPresentation {
  let content: AnyView
  let dismissesOnScrimTap: Bool
  let dismiss: @MainActor () -> Void
}

nonisolated struct ZenDialogPreferenceKey: PreferenceKey {
  static var defaultValue: ZenDialogPresentation? { nil }
  static func reduce(value: inout ZenDialogPresentation?, nextValue: () -> ZenDialogPresentation?) {
    value = value ?? nextValue()
  }
}

struct ZenDialogLayer: View {
  let presentation: ZenDialogPresentation

  var body: some View {
    ZStack {
      Button {
        if presentation.dismissesOnScrimTap { presentation.dismiss() }
      } label: {
        Rectangle()
          .fill(ZenColor.scrim)
          .ignoresSafeArea()
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .focusable(false)
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
  let dismissesOnScrimTap: Bool
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
            Button("") { isPresented = false }
              .keyboardShortcut(.cancelAction)
              .opacity(0)
              .accessibilityHidden(true)
          }
      ),
      dismissesOnScrimTap: dismissesOnScrimTap,
      dismiss: { isPresented = false })
  }
}

extension View {
  func zenDialog<Dialog: View>(
    isPresented: Binding<Bool>,
    dismissesOnScrimTap: Bool = true,
    @ViewBuilder dialog: @escaping () -> Dialog
  ) -> some View {
    modifier(ZenDialogModifier(isPresented: isPresented, dismissesOnScrimTap: dismissesOnScrimTap, dialog: dialog))
  }
}
