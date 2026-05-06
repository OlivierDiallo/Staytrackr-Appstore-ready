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

  /// `true` when the container was created with CloudKit sync enabled.
  private let isCloudSyncEnabled: Bool

  /// Set to `true` during `init()` when the corrupt store was wiped and replaced.
  /// The view layer reads this to show a one-time recovery alert.
  @State private var showStoreResetAlert = false
  private let storeWasReset: Bool

  init() {
    let schema = Schema(Self.modelTypes)

    // CloudKit sync is only enabled when the user has signed in with Apple.
    // This prevents silently syncing guest PII and financial data to iCloud
    // before the user has explicitly consented by signing in.
    // Check both Keychain (current) and UserDefaults (pre-migration fallback).
    let hasSignedInWithApple =
      STKeychainHelper.load(forKey: "v4_appleUserID") != nil ||
      UserDefaults.standard.string(forKey: "v4_appleUserID") != nil

    // Local-only config — no CloudKit.
    let localConfig = ModelConfiguration(
      "StayTrackrV6",
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: .none
    )

    // CloudKit-backed config — only attempted when user has signed in.
    let cloudConfig = ModelConfiguration(
      "StayTrackrV6",
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: .automatic
    )

    if hasSignedInWithApple, let c = Self.makeContainer(schema: schema, config: cloudConfig) {
      container = c
      isCloudSyncEnabled = true
      storeWasReset = false
      print("[StayTrackr] ✅ ModelContainer created WITH CloudKit sync (user signed in)")
    } else if let c = Self.makeContainer(schema: schema, config: localConfig) {
      container = c
      isCloudSyncEnabled = false
      storeWasReset = false
      print("[StayTrackr] ℹ️ Using LOCAL-ONLY store (no Sign in with Apple yet)")
    } else {
      // Store is completely unreadable.
      // Back up the corrupt files to Documents/Backups/ before wiping so data
      // can potentially be recovered, then start fresh so the app never hard-crashes.
      Self.backupStore(named: "StayTrackrV6")
      Self.deleteStore(named: "StayTrackrV6")
      if let c = Self.makeContainer(schema: schema, config: localConfig) {
        container = c
        isCloudSyncEnabled = false
        storeWasReset = true
        print("[StayTrackr] ⚠️ Corrupt store backed up and reset — LOCAL-ONLY store created")
        V4TelemetryManager.signal(.appLaunched, parameters: ["store_reset": "true"])
      } else {
        fatalError("Failed to create SwiftData ModelContainer after store wipe.")
      }
    }
    V4TelemetryManager.configure()
    V4TelemetryManager.signal(.appLaunched)
  }

  // MARK: - Helpers

  private static func makeContainer(schema: Schema, config: ModelConfiguration) -> ModelContainer? {
    do {
      return try ModelContainer(for: schema, configurations: [config])
    } catch {
      print("[StayTrackr] ModelContainer failed (cloudKit=\(config.cloudKitDatabase)): \(error)")
      return nil
    }
  }

  /// Copies the SwiftData store files to Documents/StayTrackrBackups/<timestamp>/
  /// before a destructive wipe, giving the user a chance to recover data manually.
  private static func backupStore(named name: String) {
    guard
      let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
      let documents = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask).first
    else { return }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    let stamp = formatter.string(from: Date())
    let backupDir = documents
      .appendingPathComponent("StayTrackrBackups")
      .appendingPathComponent(stamp)

    try? FileManager.default.createDirectory(at: backupDir,
                                             withIntermediateDirectories: true)

    for ext in ["", "-wal", "-shm"] {
      let src = appSupport.appendingPathComponent("\(name).store\(ext)")
      let dst = backupDir.appendingPathComponent("\(name).store\(ext)")
      try? FileManager.default.copyItem(at: src, to: dst)
    }
    print("[StayTrackr] Store backed up to \(backupDir.path)")
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
          // Surface the store-reset alert after the view hierarchy is ready.
          if storeWasReset { showStoreResetAlert = true }
        }
        .onReceive(NotificationCenter.default.publisher(
          for: UIApplication.willEnterForegroundNotification
        )) { _ in
          Task { await pollFlightsIfNeeded() }
        }
        .alert("Data Reset", isPresented: $showStoreResetAlert) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(
            "StayTrackr encountered a database problem and had to reset. " +
            "A backup of your data was saved to the Files app under " +
            "StayTrackr → StayTrackrBackups. " +
            "If you had iCloud sync enabled, your data will restore automatically."
          )
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
