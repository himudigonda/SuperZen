import Testing

@testable import SuperZenCore

@Suite struct OverlayBoardTests {
  private func shown(_ changes: [OverlayChange]) -> OverlayPresentation? {
    for change in changes {
      if case .show(let presentation) = change { return presentation }
    }
    return nil
  }

  @Test func previewNeverClosesALiveBreak() {
    var board = OverlayBoard()
    _ = board.present(.breakScreen, from: .live)
    #expect(board.present(.wellness, from: .preview).isEmpty)
    #expect(board.present(.alert, from: .preview).isEmpty)
    #expect(board.isLive(.breakScreen))
  }

  @Test func previewIsBlockedByLiveWellnessButNotByNudge() {
    var board = OverlayBoard()
    _ = board.present(.wellness, from: .live)
    #expect(board.present(.wellness, from: .preview).isEmpty)

    var nudging = OverlayBoard()
    _ = nudging.present(.nudge, from: .live)
    let changes = nudging.present(.wellness, from: .preview)
    #expect(shown(changes)?.source == .preview)
    #expect(nudging.isLive(.nudge))
  }

  @Test func liveBreakDisplacesEverythingElse() {
    var board = OverlayBoard()
    _ = board.present(.nudge, from: .live)
    _ = board.present(.alert, from: .live)
    let changes = board.present(.breakScreen, from: .live)
    #expect(changes.prefix(2) == [.hide(.nudge), .hide(.alert)])
    #expect(Set(board.visible.keys) == [.breakScreen])
  }

  @Test func nothingLiveInterruptsABreakExceptAnotherBreak() {
    var board = OverlayBoard()
    _ = board.present(.breakScreen, from: .live)
    #expect(board.present(.wellness, from: .live).isEmpty)
    #expect(board.present(.nudge, from: .live).isEmpty)
    let again = board.present(.breakScreen, from: .live)
    #expect(shown(again)?.generation == 2)
  }

  @Test func liveWellnessReplacesAPreviewAndHidesNudge() {
    var board = OverlayBoard()
    _ = board.present(.nudge, from: .live)
    _ = board.present(.wellness, from: .preview)
    let changes = board.present(.wellness, from: .live)
    #expect(changes.first == .hide(.nudge))
    #expect(board.isLive(.wellness))
  }

  @Test func staleExpiryIsIgnored() throws {
    var board = OverlayBoard()
    let first = try #require(shown(board.present(.alert, from: .live)))
    let second = try #require(shown(board.present(.alert, from: .live)))
    #expect(board.expire(first).isEmpty)
    #expect(board.visible[.alert] == second)
    #expect(board.expire(second) == [.hide(.alert)])
    #expect(board.visible.isEmpty)
  }

  @Test func dismissLiveKeepsPreviews() {
    var board = OverlayBoard()
    _ = board.present(.nudge, from: .live)
    _ = board.present(.alert, from: .preview)
    #expect(board.dismissLive() == [.hide(.nudge)])
    #expect(board.visible[.alert]?.source == .preview)
  }

  @Test func dismissingSomethingHiddenIsANoOp() {
    var board = OverlayBoard()
    #expect(board.dismiss(.alert).isEmpty)
  }

  @Test func bannerDoesNotCoverScreens() {
    #expect(!OverlayKind.breakBanner.coversScreens)
    #expect(OverlayKind.breakBanner.isBreak)
    #expect(!OverlayKind.wellness.isBreak)
  }

  @Test func bannerDisplacesNudgeAndAlert() {
    var board = OverlayBoard()
    _ = board.present(.nudge, from: .live)
    _ = board.present(.alert, from: .live)
    let changes = board.present(.breakBanner, from: .live)
    #expect(changes.prefix(2) == [.hide(.nudge), .hide(.alert)])
    #expect(Set(board.visible.keys) == [.breakBanner])
  }

  @Test func bannerDisplacesWellness() {
    var board = OverlayBoard()
    _ = board.present(.wellness, from: .live)
    let changes = board.present(.breakBanner, from: .live)
    #expect(changes.first == .hide(.wellness))
    #expect(Set(board.visible.keys) == [.breakBanner])
  }

  @Test func liveBannerRefusesEverythingButABreak() {
    var board = OverlayBoard()
    _ = board.present(.breakBanner, from: .live)
    #expect(board.present(.nudge, from: .live).isEmpty)
    #expect(board.present(.alert, from: .live).isEmpty)
    #expect(board.present(.wellness, from: .live).isEmpty)
    #expect(board.present(.nudge, from: .preview).isEmpty)
    #expect(board.present(.alert, from: .preview).isEmpty)
    #expect(board.present(.wellness, from: .preview).isEmpty)
    #expect(Set(board.visible.keys) == [.breakBanner])
  }

  @Test func aLiveBreakReplacesTheOtherBreakStyle() {
    var board = OverlayBoard()
    _ = board.present(.breakBanner, from: .live)
    #expect(board.present(.breakScreen, from: .live).first == .hide(.breakBanner))
    #expect(Set(board.visible.keys) == [.breakScreen])
    #expect(board.present(.breakBanner, from: .live).first == .hide(.breakScreen))
    #expect(Set(board.visible.keys) == [.breakBanner])
  }

  @Test func dismissLiveClearsABanner() {
    var board = OverlayBoard()
    _ = board.present(.breakBanner, from: .live)
    #expect(board.dismissLive() == [.hide(.breakBanner)])
    #expect(board.visible.isEmpty)
  }
}
