import Foundation

extension Reducer {
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
      playSound(.nudge)
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
}
