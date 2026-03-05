import SwiftUI
import SwiftData

/// Loads (or creates) the single persisted preferences row, then provides it to content.
struct V4PreferencesProvider<Content: View>: View {
  @Environment(\.modelContext) private var modelContext

  @State private var prefs: V4AppPreferences?
  private let content: (V4AppPreferences) -> Content

  init(@ViewBuilder content: @escaping (V4AppPreferences) -> Content) {
    self.content = content
  }

  var body: some View {
    Group {
      if let prefs {
        content(prefs)
      } else {
        ProgressView("Loading…")
          .task {
            // Fetch/create the single preferences row
            let loaded = V4PreferencesStore.loadOrCreate(in: modelContext)
            prefs = loaded
          }
      }
    }
  }
}
