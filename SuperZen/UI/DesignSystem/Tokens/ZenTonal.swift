import Foundation

nonisolated struct ZenTonalPalette: Hashable, Sendable {
  let hue: Double
  let chroma: Double

  init(hue: Double, chroma: Double) {
    self.hue = hue
    self.chroma = chroma
  }

  init(seed: ZenRGBA, chromaCap: Double = .infinity) {
    let oklch = ZenOKLCH(seed)
    self.init(hue: oklch.hue, chroma: min(oklch.chroma, chromaCap))
  }

  func shifted(hue offset: Double = 0, chroma newChroma: Double) -> ZenTonalPalette {
    ZenTonalPalette(hue: (hue + offset).truncatingRemainder(dividingBy: 360), chroma: newChroma)
  }

  func tone(_ tone: Double) -> ZenRGBA {
    let target = Self.luminance(forTone: tone)
    guard target > 0 else { return .black }
    guard target < 1 else { return .white }
    var low = 0.0
    var high = 1.0
    var best = ZenRGBA.black
    for _ in 0..<22 {
      let lightness = (low + high) / 2
      let candidate = ZenOKLCH(lightness: lightness, chroma: chroma, hue: hue).clampedToGamut
      best = candidate
      if candidate.relativeLuminance < target {
        low = lightness
      } else {
        high = lightness
      }
    }
    return best
  }

  static func luminance(forTone tone: Double) -> Double {
    let clamped = min(100, max(0, tone))
    let scaled = (clamped + 16) / 116
    let cubed = scaled * scaled * scaled
    return cubed > 216.0 / 24389.0 ? cubed : (116 * scaled - 16) * 27.0 / 24389.0
  }
}

nonisolated struct ZenOKLCH: Hashable, Sendable {
  let lightness: Double
  let chroma: Double
  let hue: Double

  init(lightness: Double, chroma: Double, hue: Double) {
    self.lightness = lightness
    self.chroma = chroma
    self.hue = hue
  }

  init(_ rgba: ZenRGBA) {
    let red = Self.linear(rgba.red)
    let green = Self.linear(rgba.green)
    let blue = Self.linear(rgba.blue)
    let long = cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue)
    let medium = cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue)
    let short = cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue)
    let lightness = 0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short
    let a = 1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short
    let b = 0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short
    let degrees = atan2(b, a) * 180 / .pi
    self.init(lightness: lightness, chroma: hypot(a, b), hue: degrees < 0 ? degrees + 360 : degrees)
  }

  var clampedToGamut: ZenRGBA {
    if let exact = Self.inGamut(lightness: lightness, chroma: chroma, hue: hue) { return exact }
    var low = 0.0
    var high = chroma
    var best =
      Self.inGamut(lightness: lightness, chroma: 0, hue: hue)
      ?? ZenRGBA(red: lightness, green: lightness, blue: lightness)
    for _ in 0..<12 {
      let mid = (low + high) / 2
      if let candidate = Self.inGamut(lightness: lightness, chroma: mid, hue: hue) {
        best = candidate
        low = mid
      } else {
        high = mid
      }
    }
    return best
  }

  private static func inGamut(lightness: Double, chroma: Double, hue: Double) -> ZenRGBA? {
    let radians = hue * .pi / 180
    let a = chroma * cos(radians)
    let b = chroma * sin(radians)
    let long = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
    let medium = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
    let short = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
    let red = 4.0767416621 * long - 3.3077115913 * medium + 0.2309699292 * short
    let green = -1.2684380046 * long + 2.6097574011 * medium - 0.3413193965 * short
    let blue = -0.0041960863 * long - 0.7034186147 * medium + 1.7076147010 * short
    let range = -0.00001...1.00001
    guard range.contains(red), range.contains(green), range.contains(blue) else { return nil }
    return ZenRGBA(red: gamma(red), green: gamma(green), blue: gamma(blue))
  }

  private static func linear(_ channel: Double) -> Double {
    channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
  }

  private static func gamma(_ channel: Double) -> Double {
    let clamped = min(1, max(0, channel))
    return clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * pow(clamped, 1 / 2.4) - 0.055
  }
}
