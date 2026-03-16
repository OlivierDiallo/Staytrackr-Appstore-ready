import SwiftUI
import SwiftData

@main
struct StayTrackrV4App: App {

  @AppStorage("v4_didSeed") private var didSeed: Bool = false

  @State private var settings     = V4AppSettings()
  @State private var appState     = V4AppState()
  @State private var notifManager = V4NotificationManager()
  @State private var store        = STStoreManager()

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
    let schema = Schema(Self.modelTypes)

    // 1. Try CloudKit-backed store (requires iCloud capability + container in Xcode).
    //    Falls back gracefully if the device has no iCloud account or entitlement is missing.
    let cloudConfig = ModelConfiguration(
      "StayTrackrV6",
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: .automatic
    )

    // 2. Local-only fallback — explicitly opt out of CloudKit so SwiftData skips
    //    CloudKit schema validation even when iCloud entitlements are present.
    let localConfig = ModelConfiguration(
      "StayTrackrV6",
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: .none
    )

    if let c = Self.makeContainer(schema: schema, config: cloudConfig) {
      // CloudKit sync available.
      container = c
    } else if let c = Self.makeContainer(schema: schema, config: localConfig) {
      // No CloudKit — fall back to local-only.
      container = c
    } else {
      // Store is completely unreadable — wipe it and start fresh so the app never hard-crashes.
      Self.deleteStore(named: "StayTrackrV6")
      if let c = Self.makeContainer(schema: schema, config: localConfig) {
        container = c
      } else {
        fatalError("Failed to create SwiftData ModelContainer after store wipe.")
      }
    }
    V4TelemetryManager.configure()
    V4TelemetryManager.signal(.appLaunched)
  }

  // MARK: - Helpers

  private static func makeContainer(schema: Schema, config: ModelConfiguration) -> ModelContainer? {
    try? ModelContainer(for: schema, configurations: [config])
  }

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
        .environment(store)
        .modelContainer(container)
        .task {
          #if DEBUG
          await seedIfNeeded()
          #endif
          runMigrations()
          await notifManager.requestAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(
          for: UIApplication.willEnterForegroundNotification
        )) { _ in
          Task { await pollFlightsIfNeeded() }
        }
    }
  }

  // MARK: - Migrations

  @MainActor
  private func runMigrations() {
    let context = ModelContext(container)
    V4Migrations.backfillExpenseCurrency(in: context)
  }

  // MARK: - Flight Polling

  @MainActor
  private func pollFlightsIfNeeded() async {
    let ctx = ModelContext(container)
    let desc = FetchDescriptor<STBooking>()
    guard let bookings = try? ctx.fetch(desc) else { return }
    for booking in bookings where V4FlightManager.shouldPoll(booking) {
      await V4FlightManager.updateBooking(booking, context: ctx)
    }
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
