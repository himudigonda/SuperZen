import Foundation
import Testing

@testable import SuperZenCore

private func insights(
  focus: TimeInterval = 0, taken: Int = 0, skipped: Int = 0, goalMinutes: Int = 60
) -> Insights {
  var result = InsightsCalculator(calendar: .utc).compute(
    .today, at: mondayNoon, data: TelemetrySnapshot(),
    configuration: InsightsConfiguration(goals: InsightsGoals(focusMinutes: goalMinutes, breaks: 4, wellness: 4)))
  result.focus = focus
  result.breaksTaken = taken
  result.breaksSkipped = skipped
  return result
}

@Suite struct TodaySummaryTests {
  @Test func carriesFocusAndBreakCounts() {
    let summary = TodaySummary(insights: insights(focus: 1800, taken: 3, skipped: 2), focusGoal: 3600)
    #expect(summary.focus == 1800)
    #expect(summary.focusGoal == 3600)
    #expect(summary.goalFraction == 0.5)
    #expect(summary.goalPercent == 50)
    #expect(summary.breaksTaken == 3)
    #expect(summary.breaksSkipped == 2)
    #expect(summary.breaksTotal == 5)
    #expect(summary.hasActivity)
    #expect(!summary.isGoalMet)
  }

  @Test func fractionClampsAtOneWhenTheGoalIsExceeded() {
    let summary = TodaySummary(insights: insights(focus: 7200), focusGoal: 3600)
    #expect(summary.goalFraction == 1)
    #expect(summary.goalPercent == 100)
    #expect(summary.isGoalMet)
  }

  @Test func goalMetExactlyAtTheGoal() {
    let summary = TodaySummary(insights: insights(focus: 3600), focusGoal: 3600)
    #expect(summary.isGoalMet)
    #expect(summary.goalFraction == 1)
  }

  @Test(arguments: [0.0, -60, .nan, .infinity, -.infinity])
  func zeroOrHostileGoalsNeverDivideByZero(goal: TimeInterval) {
    let summary = TodaySummary(insights: insights(focus: 1200), focusGoal: goal)
    #expect(summary.goalFraction == 0)
    #expect(summary.goalPercent == 0)
    #expect(!summary.isGoalMet)
    #expect(summary.focusGoal == 0)
  }

  @Test(arguments: [-5.0, .nan, .infinity])
  func hostileFocusIsTreatedAsNone(focus: TimeInterval) {
    let summary = TodaySummary(insights: insights(focus: focus), focusGoal: 3600)
    #expect(summary.focus == 0)
    #expect(summary.goalFraction == 0)
  }

  @Test func negativeBreakCountsAreFloored() {
    let summary = TodaySummary(insights: insights(taken: -2, skipped: -1), focusGoal: 3600)
    #expect(summary.breaksTaken == 0)
    #expect(summary.breaksSkipped == 0)
    #expect(!summary.hasActivity)
  }

  @Test func emptyDayHasNoActivity() {
    let summary = TodaySummary(insights: insights(), focusGoal: 3600)
    #expect(!summary.hasActivity)
    #expect(summary.goalFraction == 0)
  }

  @Test func goalsInitialiserUsesFocusMinutes() {
    let goals = InsightsGoals(focusMinutes: 90, breaks: 4, wellness: 4)
    let summary = TodaySummary(insights: insights(focus: 2700), goals: goals)
    #expect(summary.focusGoal == 5400)
    #expect(summary.goalFraction == 0.5)
  }

  @Test func summarisesRealCalculatorOutput() {
    let session = UUID()
    let start = utcDate(2026, 11, 2, 9)
    let data = TelemetrySnapshot(
      activity: [
        ActivityInterval(sessionID: session, kind: .active, start: start, end: start.addingTimeInterval(1800))
      ],
      breaks: [
        BreakRecord(
          kind: .short, result: .completed, start: utcDate(2026, 11, 2, 9, 30), end: utcDate(2026, 11, 2, 9, 31),
          planned: 60),
        BreakRecord(
          kind: .short, result: .skipped, start: utcDate(2026, 11, 2, 10), end: utcDate(2026, 11, 2, 10, 1),
          planned: 60),
      ])
    let goals = InsightsGoals(focusMinutes: 60, breaks: 4, wellness: 4)
    let result = InsightsCalculator(calendar: .utc).compute(
      .today, at: mondayNoon, data: data, configuration: InsightsConfiguration(goals: goals))
    let summary = TodaySummary(insights: result, goals: goals)
    #expect(summary.focus == 1800)
    #expect(summary.goalFraction == 0.5)
    #expect(summary.breaksTaken == 1)
    #expect(summary.breaksSkipped == 1)
  }
}
