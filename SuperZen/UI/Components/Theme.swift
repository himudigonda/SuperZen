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
  // Exact color matches from the LookAway screenshots
  static let backgroundColor = Color(
    NSColor(red: 28 / 255, green: 28 / 255, blue: 28 / 255, alpha: 1.0))
  static let sidebarBG = Color(NSColor(red: 36 / 255, green: 36 / 255, blue: 36 / 255, alpha: 1.0))
  static let cardBG = Color(NSColor(red: 42 / 255, green: 42 / 255, blue: 42 / 255, alpha: 1.0))

  static let textPrimary = Color.white
  static let textSecondary = Color(NSColor(white: 0.6, alpha: 1.0))
  static let textSectionHeader = Color(NSColor(white: 0.5, alpha: 1.0))

  static let accent = Color.blue  // Apple standard blue for toggles

  // Gradient difficulties refined to match screenshot warmth
  static let gradientCasual = LinearGradient(
    colors: [Color(hex: "FF6B6B"), Color(hex: "FFAC5F")],
    startPoint: .topLeading, endPoint: .bottomTrailing)
  static let gradientBalanced = LinearGradient(
    colors: [Color(hex: "4D79FF"), Color(hex: "A35DFF")],
    startPoint: .topLeading, endPoint: .bottomTrailing)
  static let gradientHardcore = LinearGradient(
    colors: [Color(hex: "C92C2C"), Color(hex: "8B1E1E")],
    startPoint: .topLeading, endPoint: .bottomTrailing)

  // Legacy aliases
  static var background: Color { backgroundColor }
}

struct ZenCard<Content: View>: View {
  let content: Content
  init(@ViewBuilder content: () -> Content) { self.content = content() }
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .background(Theme.cardBG)
    .cornerRadius(10)
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
  }
}

// Standard Row
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

// Complex Feature Row (Used in Smart Pause)
struct ZenFeatureRow<Content: View>: View {
  let icon: String
  let title: String
  let subtitle: String
  let content: Content

  init(icon: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
    self.icon = icon
    self.title = title
    self.subtitle = subtitle
    self.content = content()
  }

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

// Interactive Pill for Pickers
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

// Button Pill (e.g., "Options...")
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
