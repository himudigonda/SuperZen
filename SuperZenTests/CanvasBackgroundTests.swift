import AppKit
import SwiftUI
import Testing

@testable import SuperZen

@MainActor
@Suite struct CanvasBackgroundTests {
  // Core Graphics dithers gradients, so smooth output still steps by up to 4; real seams measured 16 to 32.
  private static let ditherFloor = 6

  @Test(arguments: [
    (ColorScheme.dark, 340.0, 300.0), (.light, 340.0, 300.0), (.dark, 460.0, 232.0), (.dark, 900.0, 650.0),
  ])
  func glowsNeverDrawAHardEdge(scheme: ColorScheme, width: Double, height: Double) throws {
    let renderer = ImageRenderer(
      content: ZenCanvasBackground()
        .frame(width: width, height: height)
        .environment(\.colorScheme, scheme))
    let image = try #require(renderer.cgImage)
    let bytes = try #require(Self.rgbaBytes(of: image))
    #expect(Self.largestNeighbourStep(bytes, width: image.width, height: image.height) <= Self.ditherFloor)
  }

  private static func rgbaBytes(of image: CGImage) -> [UInt8]? {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
          bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
      return true
    }
    return drawn ? bytes : nil
  }

  private static func largestNeighbourStep(_ bytes: [UInt8], width: Int, height: Int) -> Int {
    var largest = 0
    for row in 0..<height {
      for column in 0..<width {
        let origin = (row * width + column) * 4
        let neighbours = [column + 1 < width ? origin + 4 : nil, row + 1 < height ? origin + width * 4 : nil]
        for case let neighbour? in neighbours {
          for channel in 0..<3 {
            largest = max(largest, abs(Int(bytes[origin + channel]) - Int(bytes[neighbour + channel])))
          }
        }
      }
    }
    return largest
  }
}
