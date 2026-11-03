import SwiftUI

nonisolated enum ZenAnchorPlacement: Sendable {
  case menu
  case tooltip
}

nonisolated enum ZenAnchorGeometry {
  static let margin: CGFloat = 8

  static func origin(
    size: CGSize, anchor: CGRect, bounds: CGRect, placement: ZenAnchorPlacement, gap: CGFloat
  ) -> CGPoint {
    let minX = bounds.minX + margin
    let maxX = max(minX, bounds.maxX - margin - size.width)
    let minY = bounds.minY + margin
    let maxY = max(minY, bounds.maxY - margin - size.height)
    let preferredX: CGFloat
    switch placement {
    case .menu:
      preferredX = anchor.minX + size.width <= bounds.maxX - margin ? anchor.minX : anchor.maxX - size.width
    case .tooltip:
      preferredX = anchor.midX - size.width / 2
    }
    let below = anchor.maxY + gap
    let above = anchor.minY - gap - size.height
    let preferredY = below + size.height <= bounds.maxY - margin || above < minY ? below : above
    return CGPoint(x: min(maxX, max(minX, preferredX)), y: min(maxY, max(minY, preferredY)))
  }
}

struct ZenAnchoredLayout: Layout {
  let anchor: CGRect
  let placement: ZenAnchorPlacement
  let gap: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    proposal.replacingUnspecifiedDimensions()
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard let subview = subviews.first else { return }
    let maxHeight = max(0, bounds.height - ZenAnchorGeometry.margin * 2)
    let maxWidth = max(0, bounds.width - ZenAnchorGeometry.margin * 2)
    let measured = subview.sizeThatFits(ProposedViewSize(width: nil, height: maxHeight))
    let size = CGSize(width: min(measured.width, maxWidth), height: min(measured.height, maxHeight))
    let origin = ZenAnchorGeometry.origin(
      size: size, anchor: anchor.offsetBy(dx: bounds.minX, dy: bounds.minY), bounds: bounds, placement: placement,
      gap: gap)
    subview.place(at: origin, anchor: .topLeading, proposal: ProposedViewSize(size))
  }
}
