import Foundation

extension Int {
  nonisolated init(saturating value: Double) {
    if value.isNaN {
      self = 0
    } else if value >= Double(Int.max) {
      self = .max
    } else if value <= Double(Int.min) {
      self = .min
    } else {
      self = Int(value)
    }
  }
}
