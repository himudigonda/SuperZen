import Foundation

extension Int {
  static let displayCeiling = 999_999_999

  static func saturating(_ value: Double) -> Int {
    guard !value.isNaN else { return 0 }
    return Int(Swift.min(Swift.max(value, -Double(displayCeiling)), Double(displayCeiling)))
  }
}
