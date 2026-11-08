import SuperZenCore
import SwiftUI

nonisolated struct WeekdaySymbol: Identifiable, Equatable, Sendable {
  let weekday: Int
  let shortLabel: String
  let fullName: String

  var id: Int { weekday }
}

nonisolated enum WeekdayOrder {
  static func symbols(for calendar: Calendar) -> [WeekdaySymbol] {
    let short = calendar.veryShortStandaloneWeekdaySymbols
    let full = calendar.standaloneWeekdaySymbols
    guard short.count == 7, full.count == 7 else { return [] }
    let first = min(7, max(1, calendar.firstWeekday))
    return (0..<7).map { offset in
      let weekday = (first - 1 + offset) % 7 + 1
      return WeekdaySymbol(
        weekday: weekday, shortLabel: short[weekday - 1], fullName: full[weekday - 1])
    }
  }

  static func toggling(_ weekday: Int, in selection: Set<Int>) -> Set<Int> {
    guard (1...7).contains(weekday) else { return selection }
    var updated = selection
    if updated.contains(weekday) {
      guard updated.count > 1 else { return selection }
      updated.remove(weekday)
    } else {
      updated.insert(weekday)
    }
    return updated
  }
}

struct WeekdayPicker: View {
  @Binding private var selection: Set<Int>
  @Environment(\.calendar) private var calendar

  init(selection: Binding<Set<Int>>) {
    self._selection = selection
  }

  init(csv: Binding<String>) {
    self._selection = Binding(
      get: { SchedulePolicy.weekdaySet(from: csv.wrappedValue) },
      set: { csv.wrappedValue = SchedulePolicy.weekdayCSV(from: $0) }
    )
  }

  var body: some View {
    HStack(spacing: ZenSpacing.xxs) {
      ForEach(WeekdayOrder.symbols(for: calendar)) { symbol in
        dayButton(symbol)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      String(localized: "Active weekdays", comment: "Weekday picker accessibility label"))
  }

  private func dayButton(_ symbol: WeekdaySymbol) -> some View {
    let isSelected = selection.contains(symbol.weekday)
    return Button {
      selection = WeekdayOrder.toggling(symbol.weekday, in: selection)
    } label: {
      Text(symbol.shortLabel)
        .font(ZenFont.labelMedium)
    }
    .buttonStyle(ZenIconButtonStyle(kind: isSelected ? .filled : .outlined, size: 32))
    .disabled(isSelected && selection.count == 1)
    .zenTooltip(symbol.fullName)
    .accessibilityLabel(symbol.fullName)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
