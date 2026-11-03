import Foundation

extension Reducer {
  var deferral: DeferralSettings { state.settings.deferral }

  var isDeferralEnabled: Bool { deferral.isActive }

  var isListedAppFrontmost: Bool {
    guard let bundleID = state.context.frontmostBundleID else { return false }
    return deferral.apps.contains(bundleID)
  }

  var shouldDeferNow: Bool {
    guard isDeferralEnabled else { return false }
    let context = state.context
    return isListedAppFrontmost
      || (deferral.duringCalls && context.isMicrophoneInUse)
      || (deferral.duringFullscreen && context.isFullscreenAppFrontmost)
  }

  mutating func settleNudgeForContext(_ block: FocusBlock) {
    guard case .nudge = state.phase, shouldDeferNow else { return }
    emit(.hideOverlays)
    state.phase = .focus(block)
  }

  mutating func deferForContext(_ block: FocusBlock) -> Bool {
    guard shouldDeferNow else { return false }
    let startedAt = (block.contextDeferralStartedAt ?? now).clamped(notAfter: now)
    let capEnd = startedAt.addingTimeInterval(deferral.cap)
    guard !now.isAtOrAfter(capEnd) else { return false }
    var deferred = block
    deferred.contextDeferralStartedAt = startedAt
    deferred.deadline = now.addingTimeInterval(deferral.recheck).clamped(notAfter: capEnd)
    state.phase = .focus(deferred)
    return true
  }

  mutating func endDeferralIfContextCleared(_ block: FocusBlock, _ activity: ActivitySample) -> Bool {
    guard isDeferralEnabled, case .focus = state.phase, block.contextDeferralStartedAt != nil,
      !shouldDeferNow
    else { return false }
    var due = block
    due.deadline = now.clamped(notAfter: block.deadline)
    reachDeadline(due, activity)
    return true
  }
}

extension SessionState {
  public var isDeferringForContext: Bool {
    guard case .focus(let block) = phase, block.contextDeferralStartedAt != nil else { return false }
    return settings.deferral.isActive
  }
}
