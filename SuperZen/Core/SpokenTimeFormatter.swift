import Foundation

/// Shared VoiceOver-friendly spoken-time formatter, e.g. "2 minutes 30 seconds".
/// Consolidates the three previously-duplicated `spokenTime(_:)` helpers (menu bar label,
/// break overlay, fixed break alert) so the pluralization logic — and its String Catalog
/// keys — live in exactly one place.
enum SpokenTimeFormatter {
  static func spokenTime(_ seconds: TimeInterval) -> String {
    let total = Int(saturating: max(0, ceil(seconds)))
    let mins = total / 60
    let secs = total % 60

    if mins > 0 && secs > 0 {
      return String(
        localized: "\(mins) minute \(secs) second",
        comment: "VoiceOver spoken countdown, both minutes and seconds nonzero")
    }
    if mins > 0 {
      return String(
        localized: "\(mins) minute", comment: "VoiceOver spoken countdown, minutes only")
    }
    return String(
      localized: "\(secs) second",
      comment: "VoiceOver spoken countdown, seconds only (also covers zero)")
  }
}
