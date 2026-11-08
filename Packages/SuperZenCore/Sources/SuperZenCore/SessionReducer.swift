import Foundation

struct Reducer {
  var state: SessionState
  var effects: [SessionEffect] = []
  let now: Date
  let calendar: Calendar

  init(state: SessionState, now: Date, calendar: Calendar) {
    self.state = state
    self.now = now
    self.calendar = calendar
  }

  var transition: Transition { Transition(state: state, effects: effects) }
  var timer: TimerSettings { state.settings.timer }

  mutating func emit(_ effect: SessionEffect) {
    effects.append(effect)
  }

  mutating func handle(_ event: SessionEvent) {
    switch event {
    case .tick(let activity): tick(activity)
    case .suspend(let cause): suspend(cause)
    case .resume(let cause): resume(cause)
    case .settingsChanged(let settings): apply(settings)
    case .startBreak: startBreakOnRequest()
    case .skipBreak: skip()
    case .snooze(let duration): snooze(duration ?? timer.snoozeDuration)
    case .extendBreak(let seconds): extendBreak(by: seconds)
    case .togglePause: togglePause()
    case .pause(let duration): pauseRequested(for: duration)
    case .postpone(let duration): postpone(duration ?? timer.snoozeDuration)
    case .context(let sample): state.context = sample
    }
  }

  mutating func tick(_ activity: ActivitySample) {
    let previous = state.lastTick
    state.lastTick = now
    guard state.suspensions.isEmpty else { return }
    state.isTyping = timer.deferWhileTyping && activity.isTyping

    var delta = previous.map { max(0, now.timeIntervalSince($0)) } ?? 0
    if let previous, delta > SessionEngine.maxTickGap {
      recoverFromGap(since: previous)
      delta = 0
    }
    state.lastInputAt = now.addingTimeInterval(-activity.secondsSinceInput)

    if enforceSchedule() { return }
    firePlannedBreaks()

    switch state.phase {
    case .paused(let pause):
      resumeIfTimedPauseExpired(pause)
    case .naturalBreak(let since):
      if activity.secondsSinceInput < timer.idleThreshold {
        let returnedAt = now.addingTimeInterval(-activity.secondsSinceInput)
        returnFromNaturalBreak(lasting: returnedAt.timeIntervalSince(since))
      }
    case .focus(let block), .nudge(let block):
      account(delta, activity)
      if startNaturalBreakIfIdle(block) { return }
      advance(holdingForTyping(block, by: delta), activity)
    case .wellness(let pulse):
      account(delta, activity)
      guard now.isAtOrAfter(pulse.endsAt) else { return }
      emit(.hideOverlays)
      emit(.telemetry(.wellnessEnded(pulse.kind, completed: true)))
      state.phase = .focus(pulse.focus)
      advance(pulse.focus, activity)
    case .onBreak(let session):
      if now.isAtOrAfter(session.deadline) { completeBreak(session, rested: session.elapsed(at: now)) }
    }
  }

  mutating func account(_ delta: TimeInterval, _ activity: ActivitySample) {
    guard delta > 0 else { return }
    if activity.secondsSinceInput < timer.idleThreshold {
      state.continuousActive += delta
      emit(.telemetry(.activeTime(delta)))
    } else {
      emit(.telemetry(.idleTime(delta)))
    }
  }

  mutating func startNaturalBreakIfIdle(_ block: FocusBlock) -> Bool {
    let idleSince = idleStart(within: block)
    guard now.timeIntervalSince(idleSince) >= timer.naturalBreakThreshold else { return false }
    if case .nudge = state.phase { emit(.hideOverlays) }
    emit(.telemetry(.focusEnded))
    state.phase = .naturalBreak(since: idleSince)
    return true
  }

  func idleStart(within block: FocusBlock, before moment: Date? = nil) -> Date {
    let ceiling = moment ?? now
    let lastInput = (state.lastInputAt ?? ceiling).clamped(notAfter: ceiling)
    guard let startedAt = block.startedAt else { return lastInput }
    return lastInput.clamped(notBefore: startedAt).clamped(notAfter: ceiling)
  }

  mutating func advance(_ block: FocusBlock, _ activity: ActivitySample) {
    settleNudgeForContext(block)
    if endDeferralIfContextCleared(block, activity) { return }
    if now.isAtOrAfter(block.deadline) {
      reachDeadline(block, activity)
      return
    }
    if case .focus = state.phase {
      if shouldDeferNow { return }
      if block.remaining(at: now) <= timer.nudgeLeadTime {
        state.phase = .nudge(block)
        emit(.showNudge)
        return
      }
      fireWellnessIfDue(block, activity)
    }
  }

  mutating func reachDeadline(_ block: FocusBlock, _ activity: ActivitySample) {
    if deferForContext(block) { return }
    if warnBeforeUnannouncedBreak(block) { return }
    if state.isTyping && block.typingHeld < timer.typingDeferralCap {
      var deferred = block
      deferred.deadline = now
      if case .nudge = state.phase {} else { emit(.showNudge) }
      state.phase = .nudge(deferred)
      return
    }
    startBreak(kind: state.nextBreakKind, focusRemaining: nil)
  }

  mutating func warnBeforeUnannouncedBreak(_ block: FocusBlock) -> Bool {
    guard case .focus = state.phase, timer.nudgeLeadTime > 0 else { return false }
    var warned = block
    warned.deadline = now.addingTimeInterval(timer.nudgeLeadTime)
    state.phase = .nudge(warned)
    emit(.showNudge)
    return true
  }

  mutating func holdingForTyping(_ block: FocusBlock, by delta: TimeInterval) -> FocusBlock {
    guard case .nudge = state.phase, state.isTyping, delta > 0 else { return block }
    let held = min(delta, timer.typingDeferralCap - block.typingHeld)
    guard held > 0 else { return block }
    var holding = block
    holding.deadline = block.deadline.addingTimeInterval(held)
    holding.typingHeld += held
    state.phase = .nudge(holding)
    return holding
  }
}
