import Foundation
import Testing

private struct DesignRule: Sendable {
  let name: String
  let pattern: String
  let violation: String
  let compliant: String
  var allowed: [String] = []

  func hits(in text: String) throws -> [Int] {
    let regex = try NSRegularExpression(pattern: pattern)
    return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { index, line in
      let line = String(line)
      let range = NSRange(line.startIndex..., in: line)
      return regex.firstMatch(in: line, range: range) == nil ? nil : index + 1
    }
  }
}

private let rules: [DesignRule] = [
  DesignRule(
    name: "glass and materials", pattern: #"\.glassEffect|\.(ultraThin|thin|regular|thick|ultraThick|bar)Material\b"#,
    violation: ".background(.ultraThinMaterial)", compliant: ".background(ZenColor.surface)"),
  DesignRule(
    name: "system window blur", pattern: #"VisualEffectBlur\("#,
    violation: "VisualEffectBlur(material: .selection, blendingMode: .withinWindow)", compliant: "ZenSlider",
    allowed: ["Overlays/ZenBackgroundView.swift"]),
  DesignRule(
    name: "native button styles", pattern: #"\.buttonStyle\(\.(bordered|borderedProminent|borderless|link|plain)\)"#,
    violation: ".buttonStyle(.borderedProminent)", compliant: ".buttonStyle(.zenFilled)"),
  DesignRule(
    name: "native toggle styles", pattern: #"\.toggleStyle\(\.(switch|checkbox)\)"#,
    violation: ".toggleStyle(.switch)", compliant: ".toggleStyle(.zenSwitch)"),
  DesignRule(
    name: "native pickers and menus",
    pattern: #"\b(Picker|Menu|Slider|Stepper|DatePicker|ColorPicker)\s*(\(|\{)|\.pickerStyle|\.menuStyle"#,
    violation: "Menu {", compliant: "ZenMenu(items: items) {"),
  DesignRule(
    name: "native dialogs and popovers",
    pattern: #"\.(confirmationDialog|sheet|popover|fullScreenCover|help)\("#
      + #"|\.alert\(\s*(\"|Text|String|isPresented)|NSAlert\b"#,
    violation: #".confirmationDialog("Sure?", isPresented: $x)"#, compliant: ".zenDialog(isPresented: $x)"),
  DesignRule(
    name: "native progress, field and divider",
    pattern: #"\b(ProgressView|Divider|TextField|SecureField|TextEditor)\("#,
    violation: "ProgressView(value: 1)", compliant: "ZenLinearProgress(value: 1)"),
  DesignRule(
    name: "split view and toolbar", pattern: #"\bNavigationSplitView\b|\.toolbar\b"#,
    violation: "NavigationSplitView {", compliant: "CustomSidebar(selection: $x)"),
  DesignRule(
    name: "raw colours",
    pattern: #"\bColor\(|Color\.(white|black|gray|red|blue|green|orange|yellow|pink|purple)"#
      + #"|\.(white|black)\.opacity|fill\(\.(white|black)\)|ZenRGBA\(|\.foregroundColor"#,
    violation: ".fill(.white.opacity(0.1))", compliant: ".fill(ZenColor.surfaceContainer)",
    allowed: ["MenuBar/MenuBarLabel.swift"]),
  DesignRule(
    name: "raw fonts", pattern: #"Font\.system|\.font\(\.|NSFont\."#,
    violation: ".font(.system(size: 12))", compliant: ".font(ZenFont.bodySmall)"),
  DesignRule(
    name: "raw shadows", pattern: #"\.shadow\("#, violation: ".shadow(radius: 4)", compliant: ".zenElevation(.level1)"),
  DesignRule(
    name: "raw radii", pattern: #"cornerRadius: [0-9]"#,
    violation: "RoundedRectangle(cornerRadius: 13)", compliant: "RoundedRectangle(cornerRadius: ZenRadius.md)"),
  DesignRule(
    name: "legacy tokens",
    pattern: #"ZenGradient|ZenControlButtonStyle|ZenQuietButtonStyle"#
      + #"|ZenColor\.(textPrimary|textSecondary|textTertiary|accent|onAccent|danger|canvas|divider"#
      + #"|surfaceStroke|controlStroke)\b"#,
    violation: "ZenColor.textPrimary", compliant: "ZenColor.onSurface"),
]

struct DesignSystemEnforcementTests {
  private static let sourceRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("SuperZen")

  private static func productFiles() throws -> [URL] {
    let directories = ["UI", "App"].map { sourceRoot.appendingPathComponent($0) }
    var files: [URL] = []
    for directory in directories {
      let enumerator = try #require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
      for case let url as URL in enumerator where url.pathExtension == "swift" {
        if !url.path.contains("/UI/DesignSystem/") { files.append(url) }
      }
    }
    return files
  }

  @Test func scanCoversEveryScreen() throws {
    let names = try Self.productFiles().map(\.lastPathComponent)
    #expect(names.count >= 25)
    for expected in [
      "ContentView.swift", "MenuBarPopover.swift", "OnboardingView.swift", "BreakOverlayView.swift",
      "InsightsView.swift", "GeneralSettingsView.swift", "FixedBreakAlertView.swift",
    ] {
      #expect(names.contains(expected))
    }
  }

  @Test func everyRuleCatchesItsViolationAndAllowsItsCompliantForm() throws {
    for rule in rules {
      #expect(try !rule.hits(in: rule.violation).isEmpty, "\(rule.name) missed \(rule.violation)")
      #expect(try rule.hits(in: rule.compliant).isEmpty, "\(rule.name) flagged \(rule.compliant)")
    }
  }

  @Test func screensUseOnlyTheMaterialDesignSystem() throws {
    var findings: [String] = []
    for file in try Self.productFiles() {
      let text = try String(contentsOf: file, encoding: .utf8)
      for rule in rules where !rule.allowed.contains(where: { file.path.hasSuffix($0) }) {
        for line in try rule.hits(in: text) {
          findings.append("\(file.lastPathComponent):\(line) \(rule.name)")
        }
      }
    }
    #expect(findings.isEmpty, "\(findings.joined(separator: "\n"))")
  }

  @Test func designSystemComponentsAvoidGlassAndLegacyTokens() throws {
    let directory = Self.sourceRoot.appendingPathComponent("UI/DesignSystem/Components")
    let enforced = rules.filter { ["glass and materials", "legacy tokens"].contains($0.name) }
    var findings: [String] = []
    for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
      let text = try String(contentsOf: file, encoding: .utf8)
      for rule in enforced {
        for line in try rule.hits(in: text) {
          findings.append("\(file.lastPathComponent):\(line) \(rule.name)")
        }
      }
    }
    #expect(findings.isEmpty, "\(findings.joined(separator: "\n"))")
  }
}
