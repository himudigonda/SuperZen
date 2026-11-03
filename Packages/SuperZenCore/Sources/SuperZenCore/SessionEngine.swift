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
    var current = state
    if let lastTick = state.lastTick, now < lastTick {
      current = state.rebased(by: now.timeIntervalSince(lastTick))
    }
    var reducer = Reducer(state: current, now: now, calendar: calendar)
    reducer.handle(event)
    return reducer.transition
  }
}
