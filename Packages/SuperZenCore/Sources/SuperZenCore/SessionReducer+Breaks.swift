import Foundation

extension Reducer {
  mutating func startBreak(kind: BreakKind, focusRemaining: TimeInterval?) {
    switch state.phase {
    case .nudge:
      emit(.hideOverlays)
    case .wellness(let pulse):
      emit(.hideOverlays)
      emit(.telemetry(.wellnessEnded(pulse.kind, completed: false)))
    default:
      break
    }
    if state.hasOpenFocusSession { emit(.telemetry(.focusEnded)) }
    countCycle(kind)
    state.phase = .onBreak(
      BreakSession(
        kind: kind, planned: timer.duration(of: kind), startedAt: now,
        focusRemainingBeforeBreak: focusRemaining))
    emit(.showBreak(kind))
    emit(.play(.breakStart))
  }

  mutating func countCycle(_ kind: BreakKind) {
    state.cyclesSinceLongBreak = kind == .long ? 0 : state.cyclesSinceLongBreak + 1
  }

  mutating func creditNaturalBreak(lasting duration: TimeInterval) {
    if duration >= timer.longBreakDuration {
      state.cyclesSinceLongBreak = 0
      recordNaturalBreak(.long, lasting: duration)
    } else if duration >= timer.naturalBreakThreshold {
      state.cyclesSinceLongBreak += 1
      recordNaturalBreak(.short, lasting: duration)
    }
    state.continuousActive = 0
  }

  mutating func returnFromNaturalBreak(lasting duration: TimeInterval) {
    shiftWellness(by: duration)
    creditNaturalBreak(lasting: duration)
    emit(.telemetry(.focusStarted))
    beginFocus()
  }

  mutating func recordNaturalBreak(_ kind: BreakKind, lasting duration: TimeInterval) {
    let outcome = BreakOutcome(kind: kind, completed: true, rested: duration, planned: timer.duration(of: kind))
    emit(.telemetry(.naturalBreak(outcome)))
  }

  mutating func completeBreak(_ session: BreakSession, rested: TimeInterval) {
    emit(.hideOverlays)
    emit(.play(.breakEnd))
    finishBreak(session, completed: true, rested: rested)
  }

  mutating func finishBreak(_ session: BreakSession, completed: Bool, rested: TimeInterval) {
    emit(
      .telemetry(
        .breakEnded(BreakOutcome(kind: session.kind, completed: completed, rested: rested, planned: session.planned))))
    emit(.telemetry(.focusStarted))
    state.continuousActive = 0
    if !timer.resetFocusAfterBreak, let remaining = session.focusRemainingBeforeBreak, remaining >= 1 {
      beginFocus(remaining: remaining)
    } else {
      beginFocus()
    }
    deferRemindersMissedDuringBreak()
  }

  mutating func deferRemindersMissedDuringBreak() {
    guard case .focus(let block) = state.phase else { return }
    let midpoint = block.remaining(at: now) / 2
    for (kind, due) in state.wellnessDue where due.isAtOrBefore(now) {
      state.wellnessDue[kind] = now.addingTimeInterval(min(state.settings.wellness[kind].interval, midpoint))
    }
  }

  mutating func beginFocus(remaining: TimeInterval? = nil) {
    state.phase = .focus(FocusBlock(deadline: now.addingTimeInterval(remaining ?? timer.workDuration), startedAt: now))
  }

  mutating func startBreakOnRequest() {
    let focusRemaining: TimeInterval?
    switch state.phase {
    case .onBreak:
      return
    case .paused(let pause):
      guard pause.reason != .system else { return }
      if case .onBreak = pause.resume {
        resumeFromPause(pause)
        return
      }
      if pause.reason == .schedule { state.scheduleOverride = true }
      state.lastTick = now
      shiftWellness(by: now.timeIntervalSince(pause.since))
      if case .focus(let remaining) = pause.resume { focusRemaining = remaining } else { focusRemaining = nil }
    case .naturalBreak:
      focusRemaining = nil
    case .focus(let block), .nudge(let block):
      focusRemaining = block.remaining(at: now)
    case .wellness(let pulse):
      focusRemaining = pulse.focus.remaining(at: now)
    }
    startBreak(kind: state.nextBreakKind, focusRemaining: focusRemaining)
  }

  mutating func skip() {
    switch state.phase {
    case .onBreak(let session):
      guard state.canSkip(at: now) else { return }
      emit(.hideOverlays)
      finishBreak(session, completed: false, rested: session.elapsed(at: now))
    case .nudge:
      guard state.settings.skipPolicy.difficulty != .hardcore else { return }
      let kind = state.nextBreakKind
      emit(.hideOverlays)
      countCycle(kind)
      let skipped = BreakSession(kind: kind, planned: timer.duration(of: kind), startedAt: now)
      finishBreak(skipped, completed: false, rested: 0)
    default:
      return
    }
  }

  mutating func snooze(_ duration: TimeInterval) {
    guard case .nudge(let block) = state.phase, duration > 0 else { return }
    emit(.hideOverlays)
    let base = block.deadline.clamped(notBefore: now)
    state.phase = .focus(
      FocusBlock(deadline: base.addingTimeInterval(min(duration, Settings.maximumDuration)), startedAt: block.startedAt)
    )
  }

  mutating func extendBreak(by seconds: TimeInterval) {
    guard case .onBreak(var session) = state.phase, seconds > 0 else { return }
    session.planned = min(session.planned + seconds, Settings.maximumDuration)
    state.phase = .onBreak(session)
  }
}
