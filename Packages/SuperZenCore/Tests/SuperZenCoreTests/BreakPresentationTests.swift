import Testing

@testable import SuperZenCore

@Suite struct BreakPresentationTests {
  @Test func unknownOrMissingSettingFallsBackToFullScreen() {
    #expect(BreakPresentation(setting: nil) == .fullScreen)
    #expect(BreakPresentation(setting: "") == .fullScreen)
    #expect(BreakPresentation(setting: "popup") == .fullScreen)
    #expect(BreakPresentation(setting: "banner") == .banner)
    #expect(BreakPresentation(setting: "fullScreen") == .fullScreen)
  }

  @Test func hardcoreAlwaysResolvesToFullScreen() {
    #expect(BreakPresentation.banner.effective(for: .hardcore) == .fullScreen)
    #expect(BreakPresentation.fullScreen.effective(for: .hardcore) == .fullScreen)
  }

  @Test func otherDifficultiesKeepTheChoice() {
    for difficulty in [BreakDifficulty.casual, .balanced] {
      #expect(BreakPresentation.banner.effective(for: difficulty) == .banner)
      #expect(BreakPresentation.fullScreen.effective(for: difficulty) == .fullScreen)
    }
  }

  @Test func onlyBannerOnHardcoreRaisesAnIssue() {
    #expect(BreakPresentation.banner.issue(for: .hardcore) == .bannerUnavailableInHardcore)
    #expect(BreakPresentation.banner.issue(for: .balanced) == nil)
    #expect(BreakPresentation.fullScreen.issue(for: .hardcore) == nil)
  }
}
