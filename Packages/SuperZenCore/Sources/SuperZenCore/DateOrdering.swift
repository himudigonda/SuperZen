import Foundation

// Date's >= and <= are absent from Foundation on macOS 27.2 seeds while the SDK binds them natively; calling them segfaults.
extension Date {
  public func isAtOrAfter(_ other: Date) -> Bool { !(self < other) }
  public func isAtOrBefore(_ other: Date) -> Bool { !(other < self) }
  public func clamped(notBefore floor: Date) -> Date { self < floor ? floor : self }
  public func clamped(notAfter ceiling: Date) -> Date { ceiling < self ? ceiling : self }
}
