//
//  V4FX.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 08.01.2026.
//
import Foundation
import SwiftData

// V4FXRate was removed — it was a duplicate not registered in the ModelContainer schema.
// Use STFXRate (defined in STFXRate.swift) instead.

enum V4FXStore {
  /// Returns the exchange rate to convert `from` → `to`.
  /// Returns 1 if same currency, nil if no rate found.
  static func rate(from: String, to: String, in context: ModelContext) -> Double? {
    let f = from.uppercased()
    let t = to.uppercased()
    if f == t { return 1 }

    // Direct lookup
    let direct = FetchDescriptor<STFXRate>(
      predicate: #Predicate { $0.fromCode == f && $0.toCode == t }
    )
    if let r = try? context.fetch(direct).first?.rate {
      return r
    }

    // Inverse lookup
    let inv = FetchDescriptor<STFXRate>(
      predicate: #Predicate { $0.fromCode == t && $0.toCode == f }
    )
    if let r = try? context.fetch(inv).first?.rate, r != 0 {
      return 1 / r
    }

    return nil
  }

  /// Inserts or updates an FX rate row.
  static func upsert(from: String, to: String, rate: Double, in context: ModelContext) {
    let f = from.uppercased()
    let t = to.uppercased()
    let descriptor = FetchDescriptor<STFXRate>(
      predicate: #Predicate { $0.fromCode == f && $0.toCode == t }
    )

    if let existing = try? context.fetch(descriptor).first {
      existing.rate = rate
      existing.updatedAt = .now
      return
    }

    context.insert(STFXRate(fromCode: f, toCode: t, rate: rate))
  }
}
