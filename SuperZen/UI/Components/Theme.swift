import SwiftUI

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

  // Gradient difficulties
  static let gradientCasual = LinearGradient(
    colors: [Color(red: 0.9, green: 0.3, blue: 0.4), Color(red: 0.9, green: 0.6, blue: 0.2)],
    startPoint: .topLeading, endPoint: .bottomTrailing)
  static let gradientBalanced = LinearGradient(
    colors: [Color(red: 0.2, green: 0.4, blue: 0.8), Color(red: 0.5, green: 0.2, blue: 1.0)],
    startPoint: .topLeading, endPoint: .bottomTrailing)
  static let gradientHardcore = LinearGradient(
    colors: [Color(red: 0.8, green: 0.2, blue: 0.2), Color(red: 0.5, green: 0.1, blue: 0.1)],
    startPoint: .topLeading, endPoint: .bottomTrailing)
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
