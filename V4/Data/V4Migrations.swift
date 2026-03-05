//
//  Migrations.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 12.01.2026.
//
import Foundation
import SwiftData

// MARK: - Schema V1 (initial release)
//
// When adding new properties or models in the future:
//   1. Copy all current model classes into a new `V4SchemaV1` namespace (typealias or copy).
//   2. Create `V4SchemaV2` with the new/updated models.
//   3. Add a MigrationStage to `V4MigrationPlan.stages`.
//   4. Update the `schemas` array to include V2.
//   5. The app's ModelContainer will handle the migration automatically on next launch.

enum V4SchemaV1: VersionedSchema {
  static var versionIdentifier = Schema.Version(1, 0, 0)

  static var models: [any PersistentModel.Type] {
    [
      STProperty.self,
      STGuest.self,
      STBooking.self,
      STExpense.self,
      STRecurringBill.self,
      STFXRate.self,
      V4AppPreferences.self
    ]
  }
}

// MARK: - Migration Plan

enum V4MigrationPlan: SchemaMigrationPlan {
  /// List all schema versions in chronological order.
  static var schemas: [any VersionedSchema.Type] {
    [V4SchemaV1.self]
  }

  /// Migration stages between versions (empty until a V2 schema is added).
  ///
  /// Example for a future lightweight migration from V1 → V2:
  ///   MigrationStage.lightweight(
  ///     fromVersion: V4SchemaV1.self,
  ///     toVersion: V4SchemaV2.self
  ///   )
  ///
  /// Example for a custom migration that needs data transformation:
  ///   MigrationStage.custom(
  ///     fromVersion: V4SchemaV1.self,
  ///     toVersion: V4SchemaV2.self,
  ///     willMigrate: nil,
  ///     didMigrate: { context in
  ///       // mutate objects here after the new schema has been applied
  ///     }
  ///   )
  static var stages: [MigrationStage] { [] }
}

// MARK: - Runtime Migrations

enum V4Migrations {
  /// Backfill empty currencyCode on STExpense rows to match the parent property's currency.
  /// This migration is safe to run on every launch; it's a no-op when all expenses already
  /// have a currencyCode set.
  @MainActor
  static func backfillExpenseCurrency(in context: ModelContext) {
    let descriptor = FetchDescriptor<STExpense>()
    guard let items = try? context.fetch(descriptor) else { return }

    var changed = false
    for e in items {
      if e.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        e.currencyCode = e.property.currencyCode
        changed = true
      }
    }

    if changed { try? context.save() }
  }
}
