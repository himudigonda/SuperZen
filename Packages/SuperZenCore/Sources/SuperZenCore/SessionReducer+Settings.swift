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
}
