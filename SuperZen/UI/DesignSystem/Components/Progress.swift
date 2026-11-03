import SwiftUI

struct ZenLinearProgress: View {
  let value: Double
  var tint: ZenColor = .primary
  var track: ZenColor = .secondaryContainer
  var height: CGFloat = 4

  var clampedValue: Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  var body: some View {
    GeometryReader { proxy in
      let gap: CGFloat = clampedValue > 0 && clampedValue < 1 ? height : 0
      let active = proxy.size.width * clampedValue
      HStack(spacing: gap) {
        if clampedValue > 0 {
          Capsule(style: .circular).fill(tint).frame(width: max(height, active - gap / 2))
        }
        if clampedValue < 1 {
          Capsule(style: .circular).fill(track)
        }
      }
    }
    .frame(height: height)
    .accessibilityElement()
    .accessibilityValue(Text(clampedValue, format: .percent.precision(.fractionLength(0))))
  }
}

struct ZenCircularProgress: View {
  let value: Double
  var lineWidth: CGFloat = 8
  var tint: ZenColor = .primary
  var track: ZenColor = .secondaryContainer

  private var clampedValue: Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  var body: some View {
    ZStack {
      Circle().stroke(track, lineWidth: lineWidth)
      Circle()
        .trim(from: 0, to: clampedValue)
        .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
    .padding(lineWidth / 2)
  }
}

struct ZenLoadingIndicator: View {
  var size: CGFloat = 24
  var lineWidth: CGFloat = 3
  var tint: ZenColor = .primary
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isRotating = false

  var body: some View {
    Circle()
      .trim(from: 0, to: 0.72)
      .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
      .frame(width: size, height: size)
      .rotationEffect(.degrees(isRotating ? 360 : 0))
      .animation(
        reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: isRotating
      )
      .onAppear { isRotating = true }
      .accessibilityHidden(true)
  }
}

struct ZenDivider: View {
  var body: some View {
    Rectangle()
      .fill(ZenColor.outlineVariant)
      .frame(height: 1)
      .accessibilityHidden(true)
  }
}

struct ZenVerticalDivider: View {
  var height: CGFloat = ZenSpacing.md

  var body: some View {
    Rectangle()
      .fill(ZenColor.outlineVariant)
      .frame(width: 1, height: height)
      .accessibilityHidden(true)
  }
}
