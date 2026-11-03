import Foundation

extension Reducer {
  static let plannedBreakGrace: TimeInterval = 300

  mutating func firePlannedBreaks() {
    guard !state.settings.plannedBreaks.isEmpty else { return }
    let weekday = calendar.component(.weekday, from: now)
    for item in state.settings.plannedBreaks where item.weekdays.contains(weekday) {
      guard let due = dueMoment(of: item), now.isAtOrAfter(due), !firedToday(item) else { continue }
      state.plannedBreaksFired[item.id] = now
      guard now.timeIntervalSince(due) <= Self.plannedBreakGrace, let remaining = focusRemainingForPlannedBreak() else {
        continue
      }
      startBreak(kind: .long, focusRemaining: remaining, plannedDuration: item.duration)
      return
    }
  }

  func dueMoment(of item: PlannedBreak) -> Date? {
    calendar.date(
      bySettingHour: item.minuteOfDay / 60, minute: item.minuteOfDay % 60, second: 0, of: now,
      matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
  }

  func firedToday(_ item: PlannedBreak) -> Bool {
    guard let fired = state.plannedBreaksFired[item.id] else { return false }
    return calendar.isDate(fired, inSameDayAs: now)
  }

  func focusRemainingForPlannedBreak() -> TimeInterval? {
    switch state.phase {
    case .focus(let block), .nudge(let block): return block.remaining(at: now)
    case .wellness(let pulse): return pulse.focus.remaining(at: now)
    case .naturalBreak, .onBreak, .paused: return nil
    }
  }

  mutating func markPlannedBreaksAlreadyDue(previous: [PlannedBreak]) {
    let weekday = calendar.component(.weekday, from: now)
    for item in state.settings.plannedBreaks where item.weekdays.contains(weekday) && !previous.contains(item) {
      guard let due = dueMoment(of: item), now.isAtOrAfter(due), !firedToday(item) else { continue }
      state.plannedBreaksFired[item.id] = now
    }
  }
}
