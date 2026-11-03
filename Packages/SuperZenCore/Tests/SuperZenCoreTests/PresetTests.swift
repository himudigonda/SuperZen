import Foundation
import Testing

@testable import SuperZenCore

private struct PresetExpectation {
  let preset: SettingsPreset
  let work: TimeInterval
  let short: TimeInterval
  let long: TimeInterval?
  let every: Int
  let difficulty: BreakDifficulty

  init(
    _ preset: SettingsPreset, work: TimeInterval, short: TimeInterval, long: TimeInterval?, every: Int,
    difficulty: BreakDifficulty
  ) {
    self.preset = preset
    self.work = work
    self.short = short
    self.long = long
    self.every = every
    self.difficulty = difficulty
  }
}

@Suite struct PresetTests {
  @Test(arguments: SettingsPreset.allCases)
  func everyPresetSurvivesValidationUnchanged(preset: SettingsPreset) {
    let applied = preset.apply(to: Settings())
    #expect(applied == applied.validated())
    #expect(applied.issues.isEmpty)
  }

  @Test(arguments: SettingsPreset.allCases)
  func everyPresetIsValidOnTopOfCustomisedSettings(preset: SettingsPreset) {
    var custom = Settings()
    custom.timer.nudgeLeadTime = 45
    custom.timer.longBreakDuration = 60
    custom.timer.shortBreakDuration = 45
    custom.timer.longBreakEvery = 2
    custom.skipPolicy.difficulty = .hardcore
    let applied = preset.apply(to: custom)
    #expect(applied == applied.validated())
    #expect(applied.issues.isEmpty)
  }

  @Test func presetsCarryTheDocumentedValues() {
    let table = [
      PresetExpectation(.eyes2020, work: 1200, short: 20, long: 300, every: 4, difficulty: .balanced),
      PresetExpectation(.pomodoro, work: 1500, short: 300, long: 900, every: 4, difficulty: .balanced),
      PresetExpectation(.deepWork, work: 3000, short: 600, long: nil, every: 0, difficulty: .casual),
      PresetExpectation(.gentle, work: 2700, short: 300, long: nil, every: 0, difficulty: .casual),
    ]
    for row in table {
      let applied = row.preset.apply(to: Settings())
      #expect(applied.timer.workDuration == row.work)
      #expect(applied.timer.shortBreakDuration == row.short)
      #expect(applied.timer.longBreakEvery == row.every)
      #expect(applied.skipPolicy.difficulty == row.difficulty)
      if let long = row.long { #expect(applied.timer.longBreakDuration == long) }
    }
  }

  @Test(arguments: SettingsPreset.allCases)
  func applyTouchesOnlyTimerDurationsAndDifficulty(preset: SettingsPreset) {
    var original = Settings()
    original.timer.deferWhileTyping = false
    original.timer.snoozeDuration = 123
    original.timer.nudgeLeadTime = 7
    original.timer.maxPostpones = 5
    original.timer.idleThreshold = 33
    original.skipPolicy.balancedLockRatio = 0.7
    original.wellness.water.interval = 999
    original.wellness.durationMultiplier = 1.5
    original.schedule.enabled = true
    original.schedule.weekdays = [3]
    original.quietHours.enabled = true
    original.deferral.apps = ["us.zoom.xos"]
    original.plannedBreaks = [PlannedBreak(id: "lunch", minuteOfDay: 750, weekdays: [2], duration: 900)]

    var applied = preset.apply(to: original)
    applied.timer.workDuration = original.timer.workDuration
    applied.timer.shortBreakDuration = original.timer.shortBreakDuration
    applied.timer.longBreakDuration = original.timer.longBreakDuration
    applied.timer.longBreakEvery = original.timer.longBreakEvery
    applied.skipPolicy.difficulty = original.skipPolicy.difficulty
    #expect(applied == original)
  }

  @Test func presetsWithoutLongBreaksKeepTheStoredLongDuration() {
    var original = Settings()
    original.timer.longBreakDuration = 777
    let applied = SettingsPreset.deepWork.apply(to: original)
    #expect(applied.timer.longBreakEvery == 0)
    #expect(applied.timer.longBreakDuration == 777)
  }

  @Test(arguments: SettingsPreset.allCases)
  func matchingRoundTripsAndApplyIsIdempotent(preset: SettingsPreset) {
    let applied = preset.apply(to: Settings())
    #expect(SettingsPreset.matching(applied) == preset)
    #expect(preset.apply(to: applied) == applied)
    #expect(preset.matches(applied))
  }

  @Test func matchingIgnoresUnrelatedSettings() {
    var settings = SettingsPreset.pomodoro.apply(to: Settings())
    settings.wellness.water.enabled = false
    settings.schedule.enabled = true
    #expect(SettingsPreset.matching(settings) == .pomodoro)
  }

  @Test func matchingIgnoresLongDurationWhenLongBreaksAreOff() {
    var settings = SettingsPreset.gentle.apply(to: Settings())
    settings.timer.longBreakDuration = 42
    #expect(SettingsPreset.matching(settings) == .gentle)
  }

  @Test func matchingRejectsAnyDrift() {
    let base = SettingsPreset.pomodoro.apply(to: Settings())
    var work = base
    work.timer.workDuration += 1
    var short = base
    short.timer.shortBreakDuration += 1
    var long = base
    long.timer.longBreakDuration += 1
    var every = base
    every.timer.longBreakEvery = 3
    var difficulty = base
    difficulty.skipPolicy.difficulty = .hardcore
    for drifted in [work, short, long, every, difficulty] {
      #expect(SettingsPreset.matching(drifted) == nil)
    }
  }

  @Test func defaultSettingsAreTheTwentyTwentyTwentyPreset() {
    #expect(SettingsPreset.matching(Settings()) == .eyes2020)
  }

  @Test func presetsAreDistinctAndIdentifiable() {
    let applied = SettingsPreset.allCases.map { $0.apply(to: Settings()).timer }
    for (index, timer) in applied.enumerated() {
      for other in applied[(index + 1)...] { #expect(timer != other) }
    }
    #expect(Set(SettingsPreset.allCases.map(\.id)).count == SettingsPreset.allCases.count)
  }
}
