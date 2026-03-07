//
//  Migrations.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 12.01.2026.
//
import Foundation
import SwiftData

// MARK: - Schema V1 (initial release)

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

// MARK: - Schema V2 (added STBooking.note + STProperty.photoData)

enum V4SchemaV2: VersionedSchema {
  static var versionIdentifier = Schema.Version(2, 0, 0)

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
  static var schemas: [any VersionedSchema.Type] {
    [V4SchemaV1.self, V4SchemaV2.self]
  }

  // Lightweight migration: SwiftData automatically adds the new optional columns
  // (STBooking.note and STProperty.photoData) without any data transformation.
  static var stages: [MigrationStage] {
    [
      MigrationStage.lightweight(
        fromVersion: V4SchemaV1.self,
        toVersion: V4SchemaV2.self
      )
    ]
  }
}

// MARK: - Runtime Migrations

enum V4Migrations {
  /// Backfill empty currencyCode on STExpense rows to match the parent property's currency.
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
