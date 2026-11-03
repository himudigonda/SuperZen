import Foundation

extension Reducer {
  var deferral: DeferralSettings { state.settings.deferral }

  var isDeferralEnabled: Bool { !deferral.apps.isEmpty && deferral.cap > 0 }

  var isListedAppFrontmost: Bool {
    guard isDeferralEnabled, let bundleID = state.context.frontmostBundleID else { return false }
    return deferral.apps.contains(bundleID)
  }

  mutating func settleNudgeForListedApp(_ block: FocusBlock) {
    guard case .nudge = state.phase, isListedAppFrontmost else { return }
    emit(.hideOverlays)
    state.phase = .focus(block)
  }

  mutating func deferForListedApp(_ block: FocusBlock) -> Bool {
    guard isListedAppFrontmost else { return false }
    let startedAt = (block.contextDeferralStartedAt ?? now).clamped(notAfter: now)
    let capEnd = startedAt.addingTimeInterval(deferral.cap)
    guard !now.isAtOrAfter(capEnd) else { return false }
    var deferred = block
    deferred.contextDeferralStartedAt = startedAt
    deferred.deadline = now.addingTimeInterval(deferral.recheck).clamped(notAfter: capEnd)
    state.phase = .focus(deferred)
    return true
  }

  mutating func endDeferralIfListedAppLeft(_ block: FocusBlock, _ activity: ActivitySample) -> Bool {
    guard isDeferralEnabled, case .focus = state.phase, block.contextDeferralStartedAt != nil,
      !isListedAppFrontmost
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
    return !settings.deferral.apps.isEmpty && settings.deferral.cap > 0
  }
}
