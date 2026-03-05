import SwiftUI

enum V4Theme {
  enum Brand {
    static let primary = Color(hex: "#1FB86E")
  }

  enum Surface {
    static let cardBackground: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial)
  }

  enum Spacing {
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 22
  }
}
