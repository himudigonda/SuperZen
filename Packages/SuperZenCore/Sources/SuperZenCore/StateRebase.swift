import Foundation

extension FocusBlock {
  func shifted(by offset: TimeInterval) -> FocusBlock {
    FocusBlock(
      deadline: deadline.addingTimeInterval(offset),
      startedAt: startedAt?.addingTimeInterval(offset),
      typingDeferralStartedAt: typingDeferralStartedAt?.addingTimeInterval(offset),
      contextDeferralStartedAt: contextDeferralStartedAt?.addingTimeInterval(offset))
  }
}

extension BreakSession {
  func shifted(by offset: TimeInterval) -> BreakSession {
    var copy = self
    copy.resumedAt = resumedAt.addingTimeInterval(offset)
    return copy
  }
}

extension Phase {
  func shifted(by offset: TimeInterval) -> Phase {
    switch self {
    case .focus(let block):
      return .focus(block.shifted(by: offset))
    case .nudge(let block):
      return .nudge(block.shifted(by: offset))
    case .naturalBreak(let since):
      return .naturalBreak(since: since.addingTimeInterval(offset))
    case .onBreak(let session):
      return .onBreak(session.shifted(by: offset))
    case .wellness(let pulse):
      return .wellness(
        WellnessPulse(
          kind: pulse.kind, endsAt: pulse.endsAt.addingTimeInterval(offset), focus: pulse.focus.shifted(by: offset)))
    case .paused(let pause):
      return .paused(pause.shifted(by: offset))
    }
  }
}

extension Pause {
  func shifted(by offset: TimeInterval) -> Pause {
    let point: ResumePoint
    switch resume {
    case .focus: point = resume
    case .naturalBreak(let since): point = .naturalBreak(since: since.addingTimeInterval(offset))
    case .onBreak(let session): point = .onBreak(session.shifted(by: offset))
    }
    return Pause(
      reason: reason, since: since.addingTimeInterval(offset), resume: point,
      awaySince: awaySince.addingTimeInterval(offset), until: until?.addingTimeInterval(offset))
  }
}

extension SessionState {
  func rebased(by offset: TimeInterval) -> SessionState {
    var copy = self
    copy.phase = phase.shifted(by: offset)
    copy.wellnessDue = wellnessDue.mapValues { $0.addingTimeInterval(offset) }
    copy.lastTick = lastTick?.addingTimeInterval(offset)
    copy.lastInputAt = lastInputAt?.addingTimeInterval(offset)
    return copy
  }
}
