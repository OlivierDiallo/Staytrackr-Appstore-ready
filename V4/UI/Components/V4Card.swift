import SwiftUI

struct V4Card<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .padding(V4Theme.Spacing.cardPadding)
    .background(V4Theme.Surface.cardBackground, in: RoundedRectangle(cornerRadius: V4Theme.Spacing.cardRadius, style: .continuous))
  }
}
