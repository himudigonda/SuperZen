import Foundation

extension Reducer {
  mutating func enforceSchedule() -> Bool {
    let schedule = state.settings.schedule
    let within = SchedulePolicy.isWithinSchedule(schedule, at: now, calendar: calendar)
    if within { state.scheduleOverride = false }

    switch state.phase {
    case .paused(let pause) where pause.reason == .schedule:
      guard within, schedule.autoResume || !schedule.enabled else { return false }
      shiftWellness(by: now.timeIntervalSince(pause.since))
      emit(.telemetry(.focusStarted))
      beginFocus()
      return true
    case .focus, .nudge, .naturalBreak, .wellness:
      guard !within, !state.scheduleOverride else { return false }
      pause(.schedule, at: now)
      return true
    case .paused, .onBreak:
      return false
    }
  }

  mutating func pause(_ reason: PauseReason, at moment: Date, until: Date? = nil) {
    let resume: ResumePoint
    var awaySince: Date?
    let sessionOpen = state.hasOpenFocusSession
    switch state.phase {
    case .paused:
      return
    case .focus(let block), .nudge(let block):
      resume = .focus(remaining: block.remaining(at: moment))
      awaySince = idleStart(within: block, before: moment)
    case .wellness(let pulse):
      emit(.telemetry(.wellnessEnded(pulse.kind, completed: false)))
      resume = .focus(remaining: pulse.focus.remaining(at: moment))
      awaySince = idleStart(within: pulse.focus, before: moment)
    case .naturalBreak(let since):
      resume = .naturalBreak(since: since)
    case .onBreak(let session):
      resume = .onBreak(session.frozen(at: moment))
    }
    emit(.hideOverlays)
    if sessionOpen { emit(.telemetry(.focusEnded)) }
    state.isTyping = false
    state.phase = .paused(
      Pause(reason: reason, since: moment, resume: resume, awaySince: awaySince, until: until))
  }

  mutating func resumeFromPause(_ pause: Pause) {
    state.lastTick = now
    shiftWellness(by: now.timeIntervalSince(pause.since))
    switch pause.resume {
    case .focus(let remaining):
      emit(.telemetry(.focusStarted))
      beginFocus(remaining: max(1, remaining))
    case .naturalBreak(let since):
      returnFromNaturalBreak(lasting: pause.since.timeIntervalSince(since))
    case .onBreak(let session):
      state.phase = .onBreak(session.resumed(at: now))
      emit(.showBreak(session.kind))
    }
  }

  mutating func resumeAfterAway(_ pause: Pause) {
    let away = now.timeIntervalSince(pause.since)
    switch pause.resume {
    case .naturalBreak(let since):
      returnFromNaturalBreak(lasting: now.timeIntervalSince(since))
    case .focus where now.timeIntervalSince(pause.awaySince) >= timer.naturalBreakThreshold:
      let idle = now.timeIntervalSince(pause.awaySince)
      shiftWellness(by: idle)
      creditNaturalBreak(lasting: idle)
      emit(.telemetry(.focusStarted))
      beginFocus()
    case .onBreak(let session) where away >= session.remaining(at: session.resumedAt):
      shiftWellness(by: away)
      finishBreak(session, completed: true, rested: session.elapsedBeforeResume + away)
    default:
      resumeFromPause(pause)
    }
  }

  mutating func recoverFromGap(since previous: Date) {
    guard !state.isPaused else { return }
    if case .naturalBreak = state.phase { return }
    pause(.system, at: previous)
    if case .paused(let pause) = state.phase { resumeAfterAway(pause) }
  }

  mutating func suspend(_ cause: SuspendCause) {
    let wasRunning = state.suspensions.isEmpty
    state.suspensions.insert(cause)
    guard wasRunning, !state.isPaused else { return }
    pause(.system, at: now)
  }

  mutating func resume(_ cause: SuspendCause) {
    guard state.suspensions.remove(cause) != nil, state.suspensions.isEmpty else { return }
    state.lastTick = now
    guard case .paused(let pause) = state.phase, pause.reason == .system else { return }
    resumeAfterAway(pause)
  }

  mutating func pauseRequested(for duration: TimeInterval?) {
    var until: Date?
    if let duration {
      guard duration.isFinite, duration > 0 else { return }
      until = now.addingTimeInterval(min(max(duration, Settings.minimumDuration), Settings.maximumDuration))
    }
    switch state.phase {
    case .paused(var current):
      guard current.reason == .user else { return }
      current.until = until
      state.phase = .paused(current)
    case .onBreak where state.settings.skipPolicy.difficulty == .hardcore:
      return
    default:
      pause(.user, at: now, until: until)
    }
  }

  mutating func resumeIfTimedPauseExpired(_ pause: Pause) {
    guard pause.reason == .user, let until = pause.until, now.isAtOrAfter(until) else { return }
    resumeFromPause(pause)
  }

  mutating func togglePause() {
    if case .onBreak = state.phase, state.settings.skipPolicy.difficulty == .hardcore { return }
    guard case .paused(let pause) = state.phase else {
      pause(.user, at: now)
      return
    }
    switch pause.reason {
    case .user:
      resumeFromPause(pause)
    case .schedule:
      state.scheduleOverride = true
      state.lastTick = now
      shiftWellness(by: now.timeIntervalSince(pause.since))
      emit(.telemetry(.focusStarted))
      beginFocus()
    case .system:
      return
    }
  }
}
