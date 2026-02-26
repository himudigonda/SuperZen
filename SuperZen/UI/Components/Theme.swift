import SwiftUI

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let alpha: UInt64
    let red: UInt64
    let green: UInt64
    let blue: UInt64
    switch hex.count {
    case 3:  // RGB (12-bit)
      (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:  // RGB (24-bit)
      (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8:  // ARGB (32-bit)
      (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (alpha, red, green, blue) = (1, 1, 1, 0)
    }
    self.init(
      .sRGB,
      red: Double(red) / 255,
      green: Double(green) / 255,
      blue: Double(blue) / 255,
      opacity: Double(alpha) / 255
    )
  }
}

enum Theme {
  private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        switch appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight]) {
        case .darkAqua, .vibrantDark:
          return dark
        default:
          return light
        }
      })
  }

  static let backgroundColor = dynamicColor(
    light: NSColor(srgbRed: 0.93, green: 0.95, blue: 0.98, alpha: 1.0),
    dark: NSColor(srgbRed: 0.07, green: 0.1, blue: 0.13, alpha: 1.0)
  )
  static let sidebarBG = Color.clear
  static let cardBG = dynamicColor(
    light: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.5),
    dark: NSColor(srgbRed: 0.2, green: 0.26, blue: 0.31, alpha: 0.42)
  )
  static let surfaceTintTop = dynamicColor(
    light: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.52),
    dark: NSColor(srgbRed: 0.22, green: 0.31, blue: 0.38, alpha: 0.34)
  )
  static let surfaceTintBottom = dynamicColor(
    light: NSColor(srgbRed: 0.87, green: 0.91, blue: 0.97, alpha: 0.42),
    dark: NSColor(srgbRed: 0.12, green: 0.17, blue: 0.22, alpha: 0.2)
  )
  static let surfaceStroke = dynamicColor(
    light: NSColor(srgbRed: 0.62, green: 0.68, blue: 0.77, alpha: 0.46),
    dark: NSColor(srgbRed: 0.57, green: 0.65, blue: 0.74, alpha: 0.34)
  )
  static let surfaceInnerHighlight = dynamicColor(
    light: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.62),
    dark: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.16)
  )
  static let divider = dynamicColor(
    light: NSColor(srgbRed: 0.6, green: 0.66, blue: 0.75, alpha: 0.34),
    dark: NSColor(srgbRed: 0.62, green: 0.7, blue: 0.8, alpha: 0.22)
  )
  static let cardShadow = dynamicColor(
    light: NSColor(srgbRed: 0.18, green: 0.24, blue: 0.33, alpha: 0.12),
    dark: NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.3)
  )
  static let pillStroke = dynamicColor(
    light: NSColor(srgbRed: 0.58, green: 0.65, blue: 0.75, alpha: 0.42),
    dark: NSColor(srgbRed: 0.58, green: 0.66, blue: 0.75, alpha: 0.3)
  )

  static let textPrimary = dynamicColor(
    light: NSColor(srgbRed: 0.09, green: 0.11, blue: 0.14, alpha: 0.96),
    dark: NSColor(srgbRed: 0.93, green: 0.95, blue: 0.98, alpha: 0.98)
  )
  static let textSecondary = dynamicColor(
    light: NSColor(srgbRed: 0.29, green: 0.33, blue: 0.4, alpha: 0.88),
    dark: NSColor(srgbRed: 0.7, green: 0.75, blue: 0.82, alpha: 0.9)
  )
  static let textSectionHeader = dynamicColor(
    light: NSColor(srgbRed: 0.34, green: 0.39, blue: 0.47, alpha: 0.88),
    dark: NSColor(srgbRed: 0.62, green: 0.69, blue: 0.77, alpha: 0.9)
  )

  static let accent = Color.accentColor

  static let gradientCasual = LinearGradient(
    colors: [Color(hex: "0D47A1"), Color(hex: "00B8D4")],
    startPoint: .topLeading, endPoint: .bottomTrailing
  )
  static let gradientBalanced = LinearGradient(
    colors: [Color(hex: "FF8F00"), Color(hex: "FFB300")],
    startPoint: .topLeading, endPoint: .bottomTrailing
  )
  static let gradientHardcore = LinearGradient(
    colors: [Color(hex: "B71C1C"), Color(hex: "D32F2F")],
    startPoint: .topLeading, endPoint: .bottomTrailing
  )

  static var background: Color {
    backgroundColor
  }
}

// MARK: - Native macOS Blur

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
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      Theme.background
      LinearGradient(
        colors: colorScheme == .dark
          ? [Color(hex: "162431").opacity(0.7), Color(hex: "0B1117").opacity(0.48)]
          : [Color.white.opacity(0.74), Color(hex: "DEE7F4").opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      RadialGradient(
        colors: [Theme.accent.opacity(colorScheme == .dark ? 0.25 : 0.12), .clear],
        center: .topLeading,
        startRadius: 30,
        endRadius: 620
      )
      .offset(x: -120, y: -170)
      RadialGradient(
        colors: [Color.cyan.opacity(colorScheme == .dark ? 0.18 : 0.08), .clear],
        center: .topTrailing,
        startRadius: 30,
        endRadius: 560
      )
      .offset(x: 110, y: -160)
      RadialGradient(
        colors: [Color.indigo.opacity(colorScheme == .dark ? 0.12 : 0.06), .clear],
        center: .bottomLeading,
        startRadius: 80,
        endRadius: 760
      )
      .offset(x: -90, y: 240)
    }
    .ignoresSafeArea()
  }
}

struct ZenSidebarBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Rectangle()
      .fill(.ultraThinMaterial)
      .overlay(
        LinearGradient(
          colors: colorScheme == .dark
            ? [Color(hex: "213243").opacity(0.18), Color.clear]
            : [Color.white.opacity(0.52), Color(hex: "DDE6F3").opacity(0.18)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(alignment: .trailing) {
        Rectangle()
          .fill(Theme.surfaceStroke.opacity(0.95))
          .frame(width: 1)
      }
  }
}

struct ZenRowDivider: View {
  var body: some View {
    Divider()
      .overlay(Theme.divider)
      .padding(.horizontal, 16)
  }
}

struct ZenCard<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .background {
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop, Theme.surfaceTintBottom],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .overlay(shape.stroke(Theme.surfaceStroke, lineWidth: 1))
    .overlay(
      shape
        .stroke(Theme.surfaceInnerHighlight, lineWidth: 0.8)
        .blur(radius: 0.3)
        .offset(y: -0.5)
        .mask(shape)
    )
    .shadow(color: Theme.cardShadow, radius: 20, x: 0, y: 8)
    .glassEffect(.regular, in: shape)
  }
}

struct ZenRow<Content: View>: View {
  let title: String
  let subtitle: String?
  let content: Content

  init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.subtitle = subtitle
    self.content = content()
  }

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.textPrimary)
        if let subtitle = subtitle {
          Text(subtitle).font(.system(size: 11, weight: .medium)).foregroundColor(
            Theme.textSecondary)
        }
      }
      Spacer()
      content
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

struct ZenFeatureRow<Content: View>: View {
  let icon: String
  let title: String
  let subtitle: String
  @ViewBuilder let content: Content

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      Image(systemName: icon)
        .font(.system(size: 18))
        .foregroundColor(Theme.textSecondary)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.textPrimary)
        Text(subtitle).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.textSecondary)
      }
      Spacer()
      content
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

struct ZenPickerPill: View {
  let text: String
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
    HStack(spacing: 8) {
      Text(text)
        .font(.system(size: 13, weight: .medium))
        .lineLimit(1)
      Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
        .foregroundColor(Theme.textSecondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background {
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop.opacity(0.9), Theme.surfaceTintBottom.opacity(0.82)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .overlay(shape.stroke(Theme.pillStroke, lineWidth: 1))
    .glassEffect(.regular, in: shape)
    .foregroundColor(Theme.textPrimary)
  }
}

extension View {
  @ViewBuilder
  func zenMenuStyle() -> some View {
    if #available(macOS 13.0, *) {
      self.menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    } else {
      self.menuStyle(.borderlessButton)
        .fixedSize()
    }
  }
}

struct ZenButtonPill: View {
  let title: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
    .buttonStyle(.glassProminent)
    .tint(Theme.accent)
    .controlSize(.small)
  }
}

struct ZenDurationPicker: View {
  let title: String
  @Binding var value: Double
  let options: [(String, Double)]

  @State private var showingCustom = false
  @State private var customHours = ""
  @State private var customMinutes = ""
  @State private var customSeconds = ""
  @State private var customError: String?

  var body: some View {
    Menu {
      ForEach(options, id: \.1) { opt in
        Button(opt.0) { value = opt.1 }
      }
      Divider()
      Button("Custom...") {
        openCustomEditor()
      }
    } label: {
      ZenPickerPill(text: formatLabel(value))
    }
    .zenMenuStyle()
    .sheet(isPresented: $showingCustom) {
      VStack(alignment: .leading, spacing: 16) {
        Text("Custom Duration")
          .font(.system(size: 24, weight: .bold))
          .foregroundColor(Theme.textPrimary)

        Text("Set \(title) in hours, minutes, and seconds.")
          .font(.system(size: 13))
          .foregroundColor(Theme.textSecondary)

        HStack(spacing: 12) {
          durationField(title: "Hours", text: $customHours)
          durationField(title: "Minutes", text: $customMinutes)
          durationField(title: "Seconds", text: $customSeconds)
        }

        if let customError {
          Text(customError)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.red.opacity(0.9))
        }

        Spacer()

        HStack {
          Spacer()
          Button("Cancel", role: .cancel) {
            showingCustom = false
            customError = nil
          }
          Button("Apply") {
            applyCustomDuration()
          }
          .keyboardShortcut(.defaultAction)
        }
      }
      .padding(20)
      .frame(width: 460, height: 230)
      .background(ZenCanvasBackground())
    }
  }

  private func durationField(title: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(Theme.textSecondary)
      TextField("0", text: text)
        .textFieldStyle(.roundedBorder)
    }
    .frame(maxWidth: .infinity)
  }

  private func openCustomEditor() {
    let total = max(1, Int(value.rounded()))
    customHours = String(total / 3600)
    customMinutes = String((total % 3600) / 60)
    customSeconds = String(total % 60)
    customError = nil
    showingCustom = true
  }

  private func applyCustomDuration() {
    let hours = Int(customHours.filter(\.isNumber)) ?? 0
    let minutes = Int(customMinutes.filter(\.isNumber)) ?? 0
    let seconds = Int(customSeconds.filter(\.isNumber)) ?? 0
    let totalSeconds = (hours * 3600) + (minutes * 60) + seconds

    guard totalSeconds >= 1 else {
      customError = "Duration must be at least 1 second."
      return
    }

    value = Double(totalSeconds)
    customError = nil
    showingCustom = false
  }

  private func formatLabel(_ totalSeconds: Double) -> String {
    let total = Int(totalSeconds)
    let hours = total / 3600
    let mins = (total % 3600) / 60
    let secs = total % 60

    if hours > 0 {
      if mins == 0 && secs == 0 {
        return "\(hours)h"
      }
      if secs == 0 {
        return "\(hours)h \(mins)m"
      }
      return "\(hours)h \(mins)m \(secs)s"
    }

    if mins > 0 {
      if secs == 0 {
        return "\(mins)m"
      }
      return "\(mins)m \(secs)s"
    }

    return "\(secs)s"
  }
}

struct ZenNavigationRow: View {
  let icon: String?
  let title: String
  let value: String

  init(icon: String? = nil, title: String, value: String) {
    self.icon = icon
    self.title = title
    self.value = value
  }

  var body: some View {
    HStack(spacing: 12) {
      if let icon = icon {
        ZStack {
          RoundedRectangle(cornerRadius: 6).fill(.thinMaterial).frame(
            width: 24, height: 24
          )
          Image(systemName: icon).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
        }
      }
      Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.textPrimary)
      Spacer()
      Text(value).font(.system(size: 13)).foregroundColor(Theme.textSecondary)
      Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(
        Theme.textSecondary
      )
    }
    .padding(.horizontal, 16).padding(.vertical, 14)
    .contentShape(Rectangle())
  }
}

struct ZenSegmentedPicker: View {
  @Binding var selection: String
  let options: [String]

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
    HStack(spacing: 0) {
      ForEach(options, id: \.self) { option in
        Button(action: { selection = option }) {
          Text(option)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(selection == option ? Theme.textPrimary : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(selection == option ? Theme.accent.opacity(0.22) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(2)
    .background {
      shape.fill(.thinMaterial)
      shape.fill(
        LinearGradient(
          colors: [Theme.surfaceTintTop.opacity(0.88), Theme.surfaceTintBottom.opacity(0.72)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
    .overlay(shape.stroke(Theme.pillStroke, lineWidth: 1))
    .glassEffect(.regular, in: shape)
  }
}
