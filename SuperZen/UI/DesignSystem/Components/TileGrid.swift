import SwiftUI

struct TileGrid<Content: View>: View {
  private let minimumTileWidth: CGFloat
  private let content: Content

  init(minimumTileWidth: CGFloat = 128, @ViewBuilder content: () -> Content) {
    self.minimumTileWidth = minimumTileWidth
    self.content = content()
  }

  var body: some View {
    TileGridLayout(minimumTileWidth: minimumTileWidth, spacing: ZenSpacing.md) {
      content
    }
  }
}

struct TileGridLayout: Layout {
  let minimumTileWidth: CGFloat
  let spacing: CGFloat

  static let wideColumns = 4
  static let narrowColumns = 2

  func columnCount(forWidth width: CGFloat?) -> Int {
    let wideWidth = CGFloat(Self.wideColumns) * minimumTileWidth + CGFloat(Self.wideColumns - 1) * spacing
    guard let width else { return Self.wideColumns }
    return width >= wideWidth ? Self.wideColumns : Self.narrowColumns
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
    let columns = columnCount(forWidth: proposal.width)
    let width = proposal.width ?? CGFloat(columns) * minimumTileWidth + CGFloat(columns - 1) * spacing
    let heights = rowHeights(columns: columns, width: width, subviews: subviews)
    let total = heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1))
    return CGSize(width: width, height: total)
  }

  func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
    let columns = columnCount(forWidth: bounds.width)
    let tileWidth = self.tileWidth(columns: columns, width: bounds.width)
    let heights = rowHeights(columns: columns, width: bounds.width, subviews: subviews)
    var y = bounds.minY
    for (row, height) in heights.enumerated() {
      for column in 0..<columns {
        let index = row * columns + column
        guard index < subviews.count else { break }
        let x = bounds.minX + CGFloat(column) * (tileWidth + spacing)
        subviews[index].place(
          at: CGPoint(x: x, y: y), anchor: .topLeading,
          proposal: ProposedViewSize(width: tileWidth, height: height))
      }
      y += height + spacing
    }
  }

  private func tileWidth(columns: Int, width: CGFloat) -> CGFloat {
    (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
  }

  private func rowHeights(columns: Int, width: CGFloat, subviews: Subviews) -> [CGFloat] {
    let tileWidth = self.tileWidth(columns: columns, width: width)
    let rowCount = (subviews.count + columns - 1) / columns
    return (0..<rowCount).map { row in
      let range = (row * columns)..<min(subviews.count, (row + 1) * columns)
      return range.map { subviews[$0].sizeThatFits(ProposedViewSize(width: tileWidth, height: nil)).height }.max() ?? 0
    }
  }
}
