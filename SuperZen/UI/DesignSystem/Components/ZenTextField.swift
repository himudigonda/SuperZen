import SwiftUI

struct ZenTextField: View {
  private let label: String
  private let prompt: String?
  @Binding private var text: String
  private let isError: Bool
  private let alignment: TextAlignment
  private let width: CGFloat?
  @FocusState private var isFocused: Bool
  @Environment(\.isEnabled) private var isEnabled

  init(
    _ label: String,
    text: Binding<String>,
    prompt: String? = nil,
    isError: Bool = false,
    alignment: TextAlignment = .leading,
    width: CGFloat? = nil
  ) {
    self.label = label
    self._text = text
    self.prompt = prompt
    self.isError = isError
    self.alignment = alignment
    self.width = width
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ZenRadius.sm, style: .continuous)
    TextField(label, text: $text, prompt: prompt.map { Text($0).foregroundStyle(ZenColor.onSurfaceVariant) })
      .textFieldStyle(.plain)
      .labelsHidden()
      .multilineTextAlignment(alignment)
      .font(ZenFont.bodyLarge)
      .foregroundStyle(ZenColor.onSurface)
      .focused($isFocused)
      .focusEffectDisabled()
      .padding(.horizontal, ZenSpacing.sm)
      .frame(width: width)
      .frame(minHeight: 40)
      .overlay {
        shape.strokeBorder(strokeStyle, lineWidth: isFocused ? 2 : 1)
      }
      .opacity(isEnabled ? 1 : ZenStateLayer.disabledContent)
      .zenAnimation(.quick, value: isFocused)
  }

  private var strokeStyle: AnyShapeStyle {
    if isError { return AnyShapeStyle(ZenColor.error) }
    return isFocused ? AnyShapeStyle(ZenColor.primary) : AnyShapeStyle(ZenColor.outline)
  }
}
