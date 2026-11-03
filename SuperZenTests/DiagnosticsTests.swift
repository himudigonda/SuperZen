import Foundation
import Testing

@testable import SuperZen

struct DiagnosticsTests {
  @Test func homePathAndCustomImagePathNeverAppear() {
    let name = "com.himudigonda.SuperZenTests.diagnostics.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let home = "/Users/alice"
    let image = "\(home)/Pictures/secret-background.png"
    defaults.set(image, forKey: SettingKey.customImagePath)
    defaults.set("com.example.private", forKey: SettingKey.deferralApps)

    let text = Diagnostics.report(
      phaseLabel: "Focusing", context: nil, defaults: defaults, homeDirectory: home
    ).text

    #expect(!text.contains(home))
    #expect(!text.contains(image))
    #expect(!text.contains("secret-background"))
    #expect(!text.contains("com.example.private"))
    #expect(text.hasPrefix("SuperZen Diagnostics\n"))
    #expect(text.contains("Phase: Focusing"))
  }

  @Test func homePathInPhaseLabelIsRedacted() {
    let text = Diagnostics.report(
      phaseLabel: "/Users/alice/Documents", context: nil, homeDirectory: "/Users/alice"
    ).text
    #expect(!text.contains("/Users/alice"))
  }
}
