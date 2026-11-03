import Foundation
import SuperZenCore

extension StateManager {
  func pause(for seconds: TimeInterval?) { send(.pause(for: seconds)) }
  func postponeBreak(by seconds: TimeInterval? = nil) { send(.postpone(seconds)) }
}
