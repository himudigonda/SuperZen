import AppKit
import SuperZenCore
import SwiftUI
import UniformTypeIdentifiers

nonisolated enum DeferralAppList {
  static let capOptions: [(String, Double)] = [
    ("5 minutes", 300),
    ("10 minutes", 600),
    ("15 minutes", 900),
    ("30 minutes", 1800),
  ]

  static func bundleIDs(fromCSV csv: String) -> [String] {
    DeferralSettings.apps(fromCSV: csv)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  static func csv(adding bundleID: String, to csv: String) -> String {
    let current = bundleIDs(fromCSV: csv)
    guard !current.contains(bundleID) else { return DeferralSettings.csv(from: current) }
    return DeferralSettings.csv(from: current + [bundleID])
  }

  static func csv(removing bundleID: String, from csv: String) -> String {
    DeferralSettings.csv(from: bundleIDs(fromCSV: csv).filter { $0 != bundleID })
  }

  static func bundleID(ofAppAt url: URL) -> String? {
    Bundle(url: url)?.bundleIdentifier.flatMap { $0.isEmpty ? nil : $0 }
  }
}

struct DeferralAppDescriptor: Equatable {
  let bundleID: String
  let name: String
  let url: URL?

  @MainActor
  init(bundleID: String, workspace: NSWorkspace = .shared) {
    self.bundleID = bundleID
    let located = workspace.urlForApplication(withBundleIdentifier: bundleID)
    url = located
    name = located.flatMap { Self.displayName(of: $0) } ?? bundleID
  }

  @MainActor
  var icon: NSImage? {
    url.map { NSWorkspace.shared.icon(forFile: $0.path) }
  }

  private static func displayName(of url: URL) -> String? {
    guard let bundle = Bundle(url: url) else { return nil }
    let candidates = [
      bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
      bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
    ]
    return candidates.compactMap { $0 }.first { !$0.isEmpty }
      ?? url.deletingPathExtension().lastPathComponent
  }
}

struct DeferralSection: View {
  @AppStorage private var duringCalls: Bool
  @AppStorage private var duringFullscreen: Bool
  @AppStorage private var appsCSV: String
  @AppStorage private var cap: Double

  init(defaults: UserDefaults = .standard) {
    let settings = DeferralSettings()
    _duringCalls = AppStorage(
      wrappedValue: settings.duringCalls, SettingKey.deferralDuringCalls, store: defaults)
    _duringFullscreen = AppStorage(
      wrappedValue: settings.duringFullscreen, SettingKey.deferralDuringFullscreen, store: defaults)
    _appsCSV = AppStorage(
      wrappedValue: DeferralSettings.csv(from: settings.apps), SettingKey.deferralApps, store: defaults)
    _cap = AppStorage(wrappedValue: settings.cap, SettingKey.deferralCap, store: defaults)
  }

  private var apps: [String] {
    Array(Set(DeferralAppList.bundleIDs(fromCSV: appsCSV))).sorted()
  }

  var body: some View {
    PageSection("Don't interrupt") {
      Card {
        LabeledToggle(
          String(localized: "During calls", comment: "Deferral settings row title"),
          subtitle: String(
            localized: "Waits while an app is using the microphone",
            comment: "Deferral settings row subtitle for the call switch"),
          isOn: $duringCalls)
        CardDivider()
        LabeledToggle(
          String(localized: "In fullscreen apps", comment: "Deferral settings row title"),
          isOn: $duringFullscreen)
        CardDivider()
        SettingRow(String(localized: "Apps", comment: "Deferral settings row title for the app list")) {
          PillButton(String(localized: "Add app…", comment: "Deferral settings button that opens the app picker")) {
            chooseApp()
          }
        }
        ForEach(apps, id: \.self) { bundleID in
          CardDivider()
          DeferralAppRow(descriptor: DeferralAppDescriptor(bundleID: bundleID)) {
            appsCSV = DeferralAppList.csv(removing: bundleID, from: appsCSV)
          }
        }
        CardDivider()
        SettingRow(String(localized: "Wait at most", comment: "Deferral settings row title for the cap")) {
          DurationPicker(
            String(localized: "Wait at most", comment: "Duration picker sheet subject"),
            value: $cap,
            options: DeferralAppList.capOptions,
            minimum: 60)
        }
      }
      Text(
        String(
          localized: "A break never waits longer than this.",
          comment: "Deferral settings note under the cap row")
      )
      .font(ZenFont.bodySmall)
      .foregroundStyle(ZenColor.onSurfaceVariant)
      .padding(.horizontal, ZenSpacing.xxs)
    }
  }

  private func chooseApp() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [.application]
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    guard panel.runModal() == .OK, let url = panel.url, let bundleID = DeferralAppList.bundleID(ofAppAt: url)
    else { return }
    appsCSV = DeferralAppList.csv(adding: bundleID, to: appsCSV)
  }
}

private struct DeferralAppRow: View {
  let descriptor: DeferralAppDescriptor
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: ZenSpacing.md) {
      icon
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: descriptor.name)
          .font(ZenFont.bodyMedium)
          .foregroundStyle(ZenColor.onSurface)
        if descriptor.name != descriptor.bundleID {
          Text(verbatim: descriptor.bundleID)
            .font(ZenFont.bodySmall)
            .foregroundStyle(ZenColor.onSurfaceVariant)
        }
      }
      Spacer(minLength: ZenSpacing.md)
      Button(action: onRemove) {
        Image(systemName: "xmark")
          .font(ZenFont.iconSmall)
      }
      .buttonStyle(ZenIconButtonStyle(size: 32))
      .accessibilityLabel(String(localized: "Remove \(descriptor.name)", comment: "Deferral app row remove button"))
    }
    .padding(.horizontal, ZenSpacing.md)
    .padding(.vertical, ZenSpacing.xs)
    .frame(minHeight: 56)
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var icon: some View {
    if let image = descriptor.icon {
      Image(nsImage: image).resizable().scaledToFit()
    } else {
      Image(systemName: "app.dashed")
        .font(ZenFont.iconMedium)
        .foregroundStyle(ZenColor.onSurfaceVariant)
    }
  }
}
