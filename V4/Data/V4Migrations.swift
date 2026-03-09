//
//  V4Migrations.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 12.01.2026.
//
import Foundation
import SwiftData

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
