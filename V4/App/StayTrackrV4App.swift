import SwiftUI
import SwiftData

@main
struct StayTrackrV4App: App {

  @AppStorage("v4_didSeed") private var didSeed: Bool = false

  @State private var settings     = V4AppSettings()
  @State private var appState     = V4AppState()
  @State private var notifManager = V4NotificationManager()

  private let container: ModelContainer

  init() {
    do {
      // No explicit migration plan needed — SwiftData auto-migrates optional
      // column additions (note, photoData) via its built-in lightweight migration.
      self.container = try ModelContainer(
        for: STProperty.self,
             STGuest.self,
             STBooking.self,
             STExpense.self,
             STRecurringBill.self,
             STFXRate.self,
             V4AppPreferences.self
      )
    } catch {
      fatalError("Failed to create SwiftData ModelContainer: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      V4RootView()
        .environment(settings)
        .environment(appState)
        .environment(notifManager)
        .modelContainer(container)
        .task {
          #if DEBUG
          await seedIfNeeded()
          #endif
          runMigrations()
          // Request permission on first launch; no-op if already decided.
          await notifManager.requestAuthorization()
        }
    }
  }

  // MARK: - Migrations

  @MainActor
  private func runMigrations() {
    let context = ModelContext(container)
    V4Migrations.backfillExpenseCurrency(in: context)
  }

  // MARK: - Seeder

  @MainActor
  private func seedIfNeeded() async {
    guard !didSeed else { return }

    let context = ModelContext(container)
    let existing = (try? context.fetchCount(FetchDescriptor<STProperty>())) ?? 0
    guard existing == 0 else {
      didSeed = true
      return
    }

    V4Seeder.seed(into: context)

    do {
      try context.save()
      didSeed = true
    } catch {
      print("Seed save failed: \(error)")
    }
  }
}
