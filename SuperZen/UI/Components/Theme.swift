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
  static let backgroundColor = Color(
    NSColor(red: 28 / 255, green: 28 / 255, blue: 28 / 255, alpha: 1.0)
  )
  static let sidebarBG = Color(NSColor(red: 36 / 255, green: 36 / 255, blue: 36 / 255, alpha: 1.0))
  static let cardBG = Color(NSColor(red: 42 / 255, green: 42 / 255, blue: 42 / 255, alpha: 1.0))

  static let textPrimary = Color.white
  static let textSecondary = Color(NSColor(white: 0.6, alpha: 1.0))
  static let textSectionHeader = Color(NSColor(white: 0.5, alpha: 1.0))

  static let accent = Color.blue

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

struct ZenCard<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .background(Theme.cardBG)
    .cornerRadius(10)
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
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
        Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.textPrimary)
        if let subtitle = subtitle {
          Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
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
        Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.textPrimary)
        Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
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
    HStack(spacing: 8) {
      Text(text).font(.system(size: 13))
      Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
    }
    .padding(.horizontal, 10).padding(.vertical, 4)
    .background(Color.white.opacity(0.1))
    .cornerRadius(6)
    .foregroundColor(Theme.textPrimary)
  }
}

struct ZenButtonPill: View {
  let title: String
  let action: () -> Void
  var body: some View {
    Button(
      action: action,
      label: {
        Text(title)
          .font(.system(size: 12, weight: .medium))
          .padding(.horizontal, 10).padding(.vertical, 4)
          .background(Color.white.opacity(0.1))
          .cornerRadius(6)
          .foregroundColor(Theme.textPrimary)
      }
    )
    .buttonStyle(.plain)
  }
}

struct ZenDurationPicker: View {
  let title: String
  @Binding var value: Double
  let options: [(String, Double)]

  @State private var showingCustom = false
  @State private var customInput = ""

  var body: some View {
    Menu {
      ForEach(options, id: \.1) { opt in
        Button(opt.0) { value = opt.1 }
      }
      Divider()
      Button("Custom...") {
        customInput = ""
        showingCustom = true
      }
    } label: {
      ZenPickerPill(text: formatLabel(value))
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .alert("Custom Duration", isPresented: $showingCustom) {
      TextField("Minutes", text: $customInput)
      Button("OK") {
        if let val = Double(customInput) {
          // Convert entered minutes to seconds for the engine
          value = val * 60
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Enter minutes for \(title)")
    }
  }

  // FIXED: Proper duration formatting (e.g., 90s -> "1m 30s")
  private func formatLabel(_ totalSeconds: Double) -> String {
    let total = Int(totalSeconds)
    if total < 60 {
      return "\(total) second\(total == 1 ? "" : "s")"
    } else if total % 60 == 0 {
      let mins = total / 60
      return "\(mins) minute\(mins == 1 ? "" : "s")"
    } else {
      let mins = total / 60
      let secs = total % 60
      return "\(mins)m \(secs)s"
    }
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
          RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)).frame(
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
    HStack(spacing: 0) {
      ForEach(options, id: \.self) { option in
        Button(action: { selection = option }) {
          Text(option)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(selection == option ? .white : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(selection == option ? Color.blue : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(2)
    .background(Color.white.opacity(0.1))
    .cornerRadius(8)
  }
}
