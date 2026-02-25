import EventKit
import Foundation

class CalendarService {
  static let shared = CalendarService()
  private let eventStore = EKEventStore()

  /// Checks if there is a 'Busy' event currently happening on any of the user's calendars.
  func isUserBusyInCalendar() -> Bool {
    // Request access if not determined
    let status = EKEventStore.authorizationStatus(for: .event)
    if status == .notDetermined {
      // Note: In a real app, we'd prompt the user in the UI first.
      eventStore.requestFullAccessToEvents { _, _ in }
      return false
    }

    guard status == .fullAccess else { return false }

    let now = Date()
    let predicate = eventStore.predicateForEvents(
      withStart: now, end: now.addingTimeInterval(60), calendars: nil)
    let events = eventStore.events(matching: predicate)

    // Filter for events that are not "All Day" and are marked as busy
    return events.contains { event in
      !event.isAllDay && event.availability == .busy
    }
  }
}
