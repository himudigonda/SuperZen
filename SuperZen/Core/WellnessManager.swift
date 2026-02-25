import Combine
import SwiftUI

@MainActor
class WellnessManager: ObservableObject {
  static let shared = WellnessManager()

  @AppStorage("postureEnabled") var postureEnabled = true
  @AppStorage("postureFrequency") var postureFrequency = 10  // Minutes
  @AppStorage("blinkEnabled") var blinkEnabled = true
  @AppStorage("blinkFrequency") var blinkFrequency = 5  // Minutes

  private var cancellables = Set<AnyCancellable>()
  private var lastPostureCheck = Date()
  private var lastBlinkCheck = Date()

  func start() {
    Timer.publish(every: 10, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in self?.checkReminders() }
      .store(in: &cancellables)
  }

  private func checkReminders() {
    // Don't nudge if the user has been idle for more than 2 minutes
    if IdleTracker.getSecondsSinceLastInput() > 120 { return }

    let now = Date()

    if postureEnabled && now.timeIntervalSince(lastPostureCheck) >= Double(postureFrequency * 60) {
      triggerNudge(type: .posture)
      lastPostureCheck = now
    }

    if blinkEnabled && now.timeIntervalSince(lastBlinkCheck) >= Double(blinkFrequency * 60) {
      triggerNudge(type: .blink)
      lastBlinkCheck = now
    }
  }

  enum NudgeType { case posture, blink }

  private func triggerNudge(type: NudgeType) {
    // This is where the micro-overlay gets triggered in later steps
    print("Triggering Wellness Nudge: \(type)")
    SoundManager.shared.play(type == .posture ? .posture : .blink)
  }
}
