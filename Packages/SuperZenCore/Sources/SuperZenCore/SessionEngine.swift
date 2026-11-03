import Foundation

public struct SessionEngine: Sendable {
  public static let maxTickGap: TimeInterval = 90

  public var calendar: Calendar

  public init(calendar: Calendar = .current) {
    self.calendar = calendar
  }

  public func start(settings: Settings, at now: Date) -> Transition {
    let validated = settings.validated()
    var state = SessionState(
      settings: validated,
      phase: .focus(FocusBlock(deadline: now.addingTimeInterval(validated.timer.workDuration), startedAt: now)))
    state.lastTick = now
    var reducer = Reducer(state: state, now: now, calendar: calendar)
    reducer.syncWellnessSchedule(previous: nil)
    reducer.emit(.telemetry(.focusStarted))
    return reducer.transition
  }

  public func reduce(_ state: SessionState, _ event: SessionEvent, at now: Date) -> Transition {
    var reducer = Reducer(state: state, now: now, calendar: calendar)
    reducer.handle(event)
    return reducer.transition
  }
}

private struct Reducer {
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

    switch state.phase {
    case .paused:
      return
    case .naturalBreak(let since):
      if activity.secondsSinceInput < timer.idleThreshold {
        let returnedAt = now.addingTimeInterval(-activity.secondsSinceInput)
        returnFromNaturalBreak(lasting: returnedAt.timeIntervalSince(since))
      }
    case .focus(let block), .nudge(let block):
      account(delta, activity)
      if startNaturalBreakIfIdle(block) { return }
      advance(block, activity)
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
    if now.isAtOrAfter(block.deadline) {
      reachDeadline(block, activity)
      return
    }
    if case .focus = state.phase {
      if block.remaining(at: now) <= timer.nudgeLeadTime {
        state.phase = .nudge(block)
        emit(.showNudge)
        return
      }
      fireWellnessIfDue(block, activity)
    }
  }

  mutating func reachDeadline(_ block: FocusBlock, _ activity: ActivitySample) {
    if state.isTyping && timer.typingDeferralCap > 0 {
      let startedAt = block.typingDeferralStartedAt ?? now
      if now.timeIntervalSince(startedAt) < timer.typingDeferralCap {
        var deferred = block
        deferred.typingDeferralStartedAt = startedAt
        if case .nudge = state.phase {} else { emit(.showNudge) }
        state.phase = .nudge(deferred)
        return
      }
    }
    startBreak(kind: state.nextBreakKind, focusRemaining: nil)
  }

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

  mutating func fireWellnessIfDue(_ block: FocusBlock, _ activity: ActivitySample) {
    let wellness = state.settings.wellness
    let quiet = SchedulePolicy.isWithinQuietHours(state.settings.quietHours, at: now, calendar: calendar)
    for kind in WellnessKind.allCases {
      let reminder = wellness[kind]
      guard reminder.enabled, let due = state.wellnessDue[kind] else { continue }
      if quiet {
        state.wellnessDue[kind] = due.clamped(notBefore: now.addingTimeInterval(reminder.interval))
        continue
      }
      guard now.isAtOrAfter(due), activity.secondsSinceInput < timer.idleThreshold else { continue }
      if state.isTyping && now.timeIntervalSince(due) < timer.typingDeferralCap { continue }
      var next = due
      while next.isAtOrBefore(now) { next = next.addingTimeInterval(reminder.interval) }
      state.wellnessDue[kind] = next
      let duration = wellness.displayDuration(of: kind)
      state.phase = .wellness(WellnessPulse(kind: kind, endsAt: now.addingTimeInterval(duration), focus: block))
      emit(.showWellness(kind, duration: duration))
      emit(.play(.nudge))
      return
    }
  }

  mutating func syncWellnessSchedule(previous: WellnessSettings?) {
    for kind in WellnessKind.allCases {
      let reminder = state.settings.wellness[kind]
      guard reminder.enabled else {
        state.wellnessDue[kind] = nil
        continue
      }
      if previous?[kind] != reminder || state.wellnessDue[kind] == nil {
        state.wellnessDue[kind] = now.addingTimeInterval(reminder.interval)
      }
    }
  }

  mutating func shiftWellness(by interval: TimeInterval) {
    guard interval > 0 else { return }
    for (kind, due) in state.wellnessDue {
      state.wellnessDue[kind] = due.addingTimeInterval(interval)
    }
  }

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

  mutating func pause(_ reason: PauseReason, at moment: Date) {
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
    state.phase = .paused(Pause(reason: reason, since: moment, resume: resume, awaySince: awaySince))
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

  mutating func apply(_ incoming: Settings) {
    let previous = state.settings
    let settings = incoming.validated()
    guard settings != previous else { return }
    state.settings = settings

    if settings.timer.workDuration != previous.timer.workDuration {
      restartFocusForNewWorkDuration()
    }
    if case .onBreak(let session) = state.phase,
      settings.timer.duration(of: session.kind) != previous.timer.duration(of: session.kind)
    {
      state.phase = .onBreak(
        BreakSession(
          kind: session.kind, planned: settings.timer.duration(of: session.kind), startedAt: now,
          focusRemainingBeforeBreak: session.focusRemainingBeforeBreak))
    }
    if !settings.timer.deferWhileTyping { state.isTyping = false }
    syncWellnessSchedule(previous: previous.wellness)
  }

  mutating func restartFocusForNewWorkDuration() {
    let fresh = FocusBlock(deadline: now.addingTimeInterval(timer.workDuration), startedAt: now)
    switch state.phase {
    case .focus:
      state.phase = .focus(fresh)
    case .nudge:
      emit(.hideOverlays)
      state.phase = .focus(fresh)
    case .wellness(var pulse):
      pulse.focus = fresh
      state.phase = .wellness(pulse)
    case .paused(var pause):
      if case .focus = pause.resume {
        pause.resume = .focus(remaining: timer.workDuration)
        state.phase = .paused(pause)
      }
    case .naturalBreak, .onBreak:
      break
    }
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
    state.phase = .focus(FocusBlock(deadline: base.addingTimeInterval(duration), startedAt: block.startedAt))
  }

  mutating func extendBreak(by seconds: TimeInterval) {
    guard case .onBreak(var session) = state.phase, seconds > 0 else { return }
    session.planned += seconds
    state.phase = .onBreak(session)
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
