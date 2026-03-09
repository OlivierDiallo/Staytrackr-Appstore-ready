import SwiftUI
import SwiftData

@main
struct StayTrackrV4App: App {

  @AppStorage("v4_didSeed") private var didSeed: Bool = false

  @State private var settings     = V4AppSettings()
  @State private var appState     = V4AppState()
  @State private var notifManager = V4NotificationManager()

  private let container: ModelContainer

  // All SwiftData model types in one place.
  private static let modelTypes: [any PersistentModel.Type] = [
    STProperty.self,
    STGuest.self,
    STBooking.self,
    STExpense.self,
    STRecurringBill.self,
    STFXRate.self,
    V4AppPreferences.self
  ]

  init() {
    // "StayTrackrV6" store name sidesteps any leftover version metadata
    // written by the old V4MigrationPlan, which caused a "duplicate checksum"
    // crash on launch.
    let config = ModelConfiguration(
      "StayTrackrV6",
      schema: Schema(Self.modelTypes),
      isStoredInMemoryOnly: false
    )
    do {
      self.container = try ModelContainer(
        for: Schema(Self.modelTypes),
        configurations: [config]
      )
    } catch {
      // Store is unreadable — wipe it and recreate so the app never hard-crashes.
      Self.deleteStore(named: "StayTrackrV6")
      do {
        self.container = try ModelContainer(
          for: Schema(Self.modelTypes),
          configurations: [config]
        )
      } catch {
        fatalError("Failed to create SwiftData ModelContainer: \(error)")
      }
    }
  }

  // MARK: - Store recovery

  private static func deleteStore(named name: String) {
    guard let dir = FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else { return }
    for ext in ["", "-wal", "-shm"] {
      let url = dir.appendingPathComponent("\(name).store\(ext)")
      try? FileManager.default.removeItem(at: url)
    }
  }

  // MARK: - Scene

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
