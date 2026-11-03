import SuperZenCore
import SwiftUI

nonisolated enum PlannedBreakList {
  static func adding(_ item: PlannedBreak, to list: [PlannedBreak]) -> [PlannedBreak] {
    (list + [item]).sorted { $0.minuteOfDay < $1.minuteOfDay }
  }

  static func removing(id: String, from list: [PlannedBreak]) -> [PlannedBreak] {
    list.filter { $0.id != id }
  }
}

struct PlannedBreaksSection: View {
  @AppStorage(SettingKey.plannedBreaks) private var storedJSON = PlannedBreak.json(from: [])
  @State private var draftMinute = 12 * 60
  @State private var draftWeekdays: Set<Int> = [2, 3, 4, 5, 6]
  @State private var draftDuration: Double = 600
  @Environment(\.calendar) private var calendar
  @Environment(\.locale) private var locale

  private var planned: [PlannedBreak] { PlannedBreak.list(fromJSON: storedJSON) }

  var body: some View {
    CardSection(
      String(localized: "Planned breaks", comment: "Break schedule section title"),
      subtitle: String(
        localized: "Fixed breaks at set times, like lunch, on the days you choose.",
        comment: "Break schedule planned breaks subtitle")
    ) {
      ForEach(planned) { item in
        row(item)
        CardDivider()
      }
      if planned.isEmpty {
        Text("No planned breaks yet")
          .font(ZenFont.bodySmall)
          .foregroundStyle(ZenColor.onSurfaceVariant)
          .padding(ZenSpacing.md)
        CardDivider()
      }
      composer
    }
  }

  private func row(_ item: PlannedBreak) -> some View {
    SettingRow(
      ZenTimeFormat.string(minuteOfDay: item.minuteOfDay, locale: locale),
      subtitle: "\(weekdaySummary(item.weekdays)) · \(DurationFormat.compact(item.duration))"
    ) {
      Button {
        storedJSON = PlannedBreak.json(from: PlannedBreakList.removing(id: item.id, from: planned))
      } label: {
        Image(systemName: "trash")
          .accessibilityHidden(true)
      }
      .buttonStyle(.zenIcon)
      .accessibilityLabel(String(localized: "Remove planned break", comment: "Planned break remove button"))
    }
  }

  private var composer: some View {
    VStack(alignment: .leading, spacing: ZenSpacing.sm) {
      HStack(spacing: ZenSpacing.sm) {
        ZenMenu(items: timeItems) {
          PickerPill(text: ZenTimeFormat.string(minuteOfDay: draftMinute, locale: locale))
        }
        .accessibilityLabel(String(localized: "Start time", comment: "Time range picker: start time label"))
        DurationPicker(
          String(localized: "Planned break length", comment: "Duration picker sheet subject"),
          value: $draftDuration,
          options: SettingsCatalog.longBreakDurationOptions,
          minimum: 5)
        Spacer(minLength: 0)
        PillButton(String(localized: "Add break", comment: "Planned break add button")) { add() }
      }
      WeekdayPicker(selection: $draftWeekdays)
    }
    .padding(ZenSpacing.md)
  }

  private var timeItems: [ZenMenuItem] {
    ZenTimeFormat.options(stepMinutes: 15, including: [draftMinute]).map { minute in
      .action(
        id: "\(minute)", ZenTimeFormat.string(minuteOfDay: minute, locale: locale),
        isSelected: minute == draftMinute
      ) { draftMinute = minute }
    }
  }

  private func add() {
    let item = PlannedBreak(
      id: UUID().uuidString, minuteOfDay: draftMinute, weekdays: draftWeekdays, duration: draftDuration)
    storedJSON = PlannedBreak.json(from: PlannedBreakList.adding(item, to: planned))
  }

  private func weekdaySummary(_ weekdays: Set<Int>) -> String {
    let symbols = calendar.shortStandaloneWeekdaySymbols
    guard symbols.count == 7 else { return "" }
    return WeekdayOrder.symbols(for: calendar)
      .filter { weekdays.contains($0.weekday) }
      .map { symbols[$0.weekday - 1] }
      .joined(separator: ", ")
  }
}
