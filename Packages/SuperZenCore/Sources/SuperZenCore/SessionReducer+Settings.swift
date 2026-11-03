import Foundation

extension Reducer {
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
      var rebuilt = session
      rebuilt.planned = settings.timer.duration(of: session.kind)
      rebuilt.elapsedBeforeResume = 0
      rebuilt.resumedAt = now
      state.phase = .onBreak(rebuilt)
    }
    markPlannedBreaksAlreadyDue(previous: previous.plannedBreaks)
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
}
